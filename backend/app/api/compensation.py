from collections.abc import Callable
from datetime import date, time
from typing import Annotated, Final

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.teacher import Teacher
from app.models.volunteering import VolunteeringRule
from app.schemas.compensation import (
    CompensationDayResponse,
    CompensationMonthResponse,
    CompensationSpanResponse,
    CompensationUpdate,
    IbanUpdate,
    RuleFiguresResponse,
    VolunteeringRuleChangeUpdate,
)
from app.services import push
from app.services.accounting_lock import lock_account
from app.services.compensation import (
    CompensationMonth,
    load_terms,
    month_compensation,
    net_of,
    rule_previews,
    set_terms,
    set_volunteering_rule,
    worked_days,
)
from app.services.push import joined
from app.services.role_service import RoleService
from app.services.volunteering_notifications import announce_volunteering_rule
from app.services.worked_hours import (
    BEGINNING,
    Span,
    month_after,
    time_of,
)

router = APIRouter(prefix="/people", tags=["compensation"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]

_STAFF_NOT_FOUND_ERROR: Final[str] = "Collaboratore non trovato"
_FUTURE_MONTH_ERROR: Final[str] = "Il mese non è ancora iniziato"


def _is_over() -> Callable[[date, time], bool]:
    now = now_in_rome()

    def over(day: date, end_time: time) -> bool:
        return day < now.date() or (day == now.date() and end_time <= now.time())

    return over


def _this_month() -> date:
    return now_in_rome().date().replace(day=1)


def _month_or_400(year: int, month: int) -> date:
    first = date(year, month, 1)

    if first > _this_month():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_FUTURE_MONTH_ERROR,
        )

    return first


async def _admin_role(
    db: AsyncSession,
    tax_code: str,
) -> AdministratorRoleEnum | None:
    return await db.scalar(
        select(Administrator.role).where(Administrator.tax_code == tax_code),
    )


# A psychologist alone has none of this: their record says it.
async def _staff_or_404(db: AsyncSession, tax_code: str) -> Staff:
    staff = await db.scalar(
        select(Staff).where(
            Staff.tax_code == tax_code,
            or_(
                Staff.tax_code.in_(select(Teacher.tax_code)),
                Staff.tax_code.in_(select(Administrator.tax_code)),
            ),
        ),
    )

    if staff is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_STAFF_NOT_FOUND_ERROR,
        )

    return staff


def _figures(pay: CompensationMonth) -> RuleFiguresResponse:
    return RuleFiguresResponse(
        volunteer_minutes=pay.volunteer_minutes,
        paid_minutes=pay.paid_minutes,
        gross=pay.gross,
        net=pay.net,
    )


def _spans(
    spans: list[Span],
    online: Callable[[Span], bool] = lambda _: False,
) -> list[CompensationSpanResponse]:
    return [
        CompensationSpanResponse(
            start_time=time_of(start),
            end_time=time_of(end),
            mode="online" if online((start, end)) else "presence",
        )
        for start, end in spans
    ]


@router.get(
    "/{tax_code}/compensation",
    response_model=CompensationMonthResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
async def get_compensation(
    tax_code: str,
    db: DbSession,
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> CompensationMonthResponse:
    tax_code = tax_code.upper()

    await _staff_or_404(db, tax_code)

    first = _month_or_400(year, month)
    timeline = await load_terms(db, tax_code)
    pay = await month_compensation(db, tax_code, first, _is_over(), timeline)
    rate = pay.terms.rate
    admin_role = await _admin_role(db, tax_code)
    previews = (
        await rule_previews(db, tax_code, first, _is_over(), timeline)
        if pay.terms.is_paid
        else None
    )
    rule = timeline.rule(first)

    return CompensationMonthResponse(
        collaboration_type=pay.terms.collaboration_type.value,
        gross_rate=rate,
        net_rate=None if rate is None else net_of(rate),
        gross=pay.gross,
        net=pay.net,
        worked_minutes=pay.worked_minutes,
        volunteer_minutes=pay.volunteer_minutes,
        paid_minutes=pay.paid_minutes,
        days=[
            CompensationDayResponse(
                date=day.day,
                worked=_spans(day.worked, day.is_online),
                volunteer=_spans(day.volunteer),
                worked_minutes=day.worked_minutes,
                volunteer_minutes=day.volunteer_minutes,
                gross=day.gross,
                net=day.net,
            )
            for day in pay.days
        ],
        money_from=timeline.start.money_from,
        opening_gross=pay.opening_gross,
        opening_net=pay.opening_net,
        opening_pending=pay.pending,
        can_edit=admin_role not in RoleService.ADMIN_ROLES_REQUIRING_UNPAID,
        volunteering=rule.value,
        volunteering_month_only=rule != timeline.standing_rule(first),
        volunteering_replaced=timeline.chosen_from(first),
        volunteering_previews=(
            None
            if previews is None
            else {choice.value: _figures(month) for choice, month in previews.items()}
        ),
    )


# For the month picker's dots.
@router.get(
    "/{tax_code}/compensation/months",
    response_model=list[date],
    dependencies=[Depends(require_role("ADMIN"))],
)
async def get_worked_months(tax_code: str, db: DbSession) -> list[date]:
    tax_code = tax_code.upper()

    await _staff_or_404(db, tax_code)

    days = await worked_days(
        db,
        tax_code,
        BEGINNING,
        month_after(_this_month()),
        _is_over(),
    )

    return sorted({day.replace(day=1) for day in days})


@router.put(
    "/{tax_code}/compensation/iban",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_role("ADMIN"))],
)
async def update_iban(
    tax_code: str,
    payload: IbanUpdate,
    db: DbSession,
) -> dict[str, str]:
    tax_code = tax_code.upper()

    staff = await _staff_or_404(db, tax_code)
    staff.iban = payload.iban

    await db.commit()

    return {"status": "ok"}


# Holds until the next change, past month or present.
@router.put(
    "/{tax_code}/compensation",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_role("ADMIN"))],
)
async def update_compensation(
    tax_code: str,
    payload: CompensationUpdate,
    db: DbSession,
) -> dict[str, str]:
    tax_code = tax_code.upper()

    await lock_account(db, tax_code)
    staff = await _staff_or_404(db, tax_code)
    first = _month_or_400(payload.year, payload.month)
    collaboration_type = CollaborationTypeEnum(payload.collaboration_type)
    admin_role = await _admin_role(db, tax_code)

    if admin_role is not None:
        RoleService.assert_collaboration_type_consistent_with_admin_role(
            admin_role,
            collaboration_type,
        )

    await set_terms(
        db,
        staff,
        first,
        collaboration_type,
        payload.gross_compensation
        if collaboration_type == CollaborationTypeEnum.PAID
        else None,
    )
    await db.commit()

    return {"status": "ok"}


# The teacher's rule from this month on, until their next change. They are told
# when a paid month of theirs counts otherwise.
@router.put(
    "/{tax_code}/compensation/volunteering",
    status_code=status.HTTP_200_OK,
)
async def update_volunteering(
    tax_code: str,
    payload: VolunteeringRuleChangeUpdate,
    db: DbSession,
    identity: Admin,
    background: BackgroundTasks,
) -> dict[str, str]:
    tax_code = tax_code.upper()

    await lock_account(db, tax_code)
    await _staff_or_404(db, tax_code)

    first = _month_or_400(payload.year, payload.month)
    rule = VolunteeringRule(payload.rule)
    paid = (await load_terms(db, tax_code)).of_month(first).is_paid
    before = await set_volunteering_rule(db, tax_code, first, rule)
    batch = (
        await announce_volunteering_rule(
            db,
            tax_code,
            first,
            rule,
            before,
            identity.tax_code,
            from_month=True,
        )
        if before is not None and paid
        else joined([])
    )
    await db.commit()
    background.add_task(push.deliver, batch)

    return {"status": "ok"}
