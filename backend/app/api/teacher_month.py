from collections.abc import Callable
from datetime import date, time
from typing import Annotated, Final

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    HTTPException,
    Path,
    Response,
    UploadFile,
    status,
)

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.core.downloads import inline_disposition
from app.core.i18n import tr
from app.models.volunteering import VolunteeringRule
from app.schemas.compensation import RuleFiguresResponse
from app.schemas.teacher_month import (
    PaymentReceiptResponse,
    PendingBandResponse,
    TeacherMonthResponse,
    TeacherMonthRowResponse,
    VolunteeringRuleUpdate,
)
from app.services import payment_receipts, push, teacher_month
from app.services.accounting_lock import lock_account
from app.services.push import joined
from app.services.teacher_month import MonthRow, MonthSummary
from app.services.volunteering_notifications import announce_volunteering_rule

router = APIRouter(prefix="/accounting/teacher-month", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]
Year = Annotated[int, Path(ge=2000, le=2100)]
Month = Annotated[int, Path(ge=1, le=12)]

_FUTURE_MONTH_ERROR: Final[tuple[str, str]] = (
    "Il mese non è ancora iniziato",
    "The month hasn't started yet",
)


def _is_over() -> Callable[[date, time], bool]:
    now = now_in_rome()

    def over(day: date, end_time: time) -> bool:
        return day < now.date() or (day == now.date() and end_time <= now.time())

    return over


def _month_or_400(year: int, month: int) -> date:
    first = date(year, month, 1)

    if first > now_in_rome().date().replace(day=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_FUTURE_MONTH_ERROR),
        )

    return first


def _row(row: MonthRow) -> TeacherMonthRowResponse:
    return TeacherMonthRowResponse(
        tax_code=row.tax_code,
        first_name=row.first_name,
        last_name=row.last_name,
        collaboration_type=row.collaboration_type.value,
        days=row.days,
        presence_days=row.presence_days,
        online_days=row.online_days,
        worked_minutes=row.worked_minutes,
        volunteer_minutes=row.volunteer_minutes,
        paid_minutes=row.paid_minutes,
        gross=row.gross,
        net=row.net,
        availabilities=row.availabilities,
        below_monthly=row.below_monthly,
        short_weeks=row.short_weeks,
        volunteering=row.volunteering.value,
        standing_volunteering=row.standing_volunteering.value,
        rule_figures=(
            None
            if row.rule_figures is None
            else {
                rule.value: RuleFiguresResponse(
                    volunteer_minutes=figures.volunteer_minutes,
                    paid_minutes=figures.paid_minutes,
                    gross=figures.gross,
                    net=figures.net,
                )
                for rule, figures in row.rule_figures.items()
            }
        ),
        receipt=(
            None
            if row.receipt is None
            else PaymentReceiptResponse(
                file_name=row.receipt.file_name,
                content_type=row.receipt.content_type,
                size=row.receipt.size,
                uploaded_at=row.receipt.uploaded_at,
            )
        ),
        opening_pending=row.opening_pending,
    )


def _month(summary: MonthSummary) -> TeacherMonthResponse:
    return TeacherMonthResponse(
        month=summary.month,
        rows=[_row(row) for row in summary.rows],
        pending=[
            PendingBandResponse(date=day, band=band) for day, band in summary.pending
        ],
        finished=summary.finished,
    )


async def _summary(db: DbSession, month: date) -> TeacherMonthResponse:
    return _month(
        await teacher_month.month_summary(db, month, now_in_rome(), _is_over()),
    )


@router.get("/{year}/{month}", response_model=TeacherMonthResponse)
async def get_month(
    year: Year,
    month: Month,
    db: DbSession,
    _: Admin,
) -> TeacherMonthResponse:
    return await _summary(db, _month_or_400(year, month))


# The only thing written here: how that month counts the unpaid hour.
@router.put(
    "/{year}/{month}/{tax_code}/volunteering",
    response_model=TeacherMonthResponse,
)
async def set_volunteering(
    year: Year,
    month: Month,
    tax_code: str,
    payload: VolunteeringRuleUpdate,
    db: DbSession,
    identity: Admin,
    background: BackgroundTasks,
) -> TeacherMonthResponse:
    first = _month_or_400(year, month)
    teacher = tax_code.upper()
    rule = VolunteeringRule(payload.rule)

    await lock_account(db, teacher)
    before = await teacher_month.set_month_volunteering(db, teacher, first, rule)
    batch = (
        joined([])
        if before is None
        else await announce_volunteering_rule(
            db,
            teacher,
            first,
            rule,
            before,
            identity.tax_code,
        )
    )
    await db.commit()
    background.add_task(push.deliver, batch)

    return await _summary(db, first)


# The bank transfer receipt of the teacher's month: a new one takes its place.
@router.put(
    "/{year}/{month}/{tax_code}/receipt",
    response_model=TeacherMonthResponse,
)
async def upload_receipt(
    year: Year,
    month: Month,
    tax_code: str,
    file: Annotated[UploadFile, File()],
    db: DbSession,
    identity: Admin,
) -> TeacherMonthResponse:
    first = _month_or_400(year, month)

    await payment_receipts.store_receipt(
        db,
        tax_code.upper(),
        first,
        file,
        identity.tax_code,
    )
    await db.commit()

    return await _summary(db, first)


@router.get("/{year}/{month}/{tax_code}/receipt")
async def download_receipt(
    year: Year,
    month: Month,
    tax_code: str,
    db: DbSession,
    _: Admin,
) -> Response:
    receipt = await payment_receipts.receipt_file(
        db,
        tax_code.upper(),
        _month_or_400(year, month),
    )

    return Response(
        content=receipt.content,
        media_type=receipt.content_type,
        headers={"Content-Disposition": inline_disposition(receipt.file_name)},
    )


@router.delete(
    "/{year}/{month}/{tax_code}/receipt",
    response_model=TeacherMonthResponse,
)
async def delete_receipt(
    year: Year,
    month: Month,
    tax_code: str,
    db: DbSession,
    _: Admin,
) -> TeacherMonthResponse:
    first = _month_or_400(year, month)

    await payment_receipts.delete_receipt(db, tax_code.upper(), first)
    await db.commit()

    return await _summary(db, first)
