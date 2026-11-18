from collections.abc import Callable
from datetime import date, time
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.models.person import Person
from app.schemas.accounting_stats import (
    AccountingMonthResponse,
    AccountingStatsResponse,
    FeeBreakEvenItem,
    FeePupilItem,
    PayerItem,
)
from app.schemas.person import PersonOption
from app.services.accounting_stats import WINDOW_MONTHS, accounting_stats

router = APIRouter(prefix="/accounting/statistics", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


def _is_over() -> Callable[[date, time], bool]:
    now = now_in_rome()

    def over(day: date, end_time: time) -> bool:
        return day < now.date() or (day == now.date() and end_time <= now.time())

    return over


async def _people(db: DbSession, tax_codes: set[str]) -> dict[str, PersonOption]:
    if not tax_codes:
        return {}

    rows = await db.execute(
        select(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
        ).where(Person.tax_code.in_(tax_codes)),
    )

    return {
        tax_code: PersonOption(
            tax_code=tax_code,
            first_name=first,
            last_name=last,
            profile_image_url=image,
        )
        for tax_code, first, last, image in rows.tuples()
    }


# The last months up to this one, or a calendar year; never both.
@router.get("", response_model=AccountingStatsResponse)
async def get_statistics(
    db: DbSession,
    _: Admin,
    months: Annotated[int | None, Query(ge=1, le=WINDOW_MONTHS)] = None,
    year: Annotated[int | None, Query(ge=2000, le=2100)] = None,
) -> AccountingStatsResponse:
    stats = await accounting_stats(
        db,
        now_in_rome(),
        _is_over(),
        months=None if year is not None else months,
        year=year,
    )
    people = await _people(
        db,
        {tax_code for tax_code, _ in stats.top_payers}
        | {pupil.tax_code for pupil in stats.fee_pupils},
    )

    return AccountingStatsResponse(
        months=[
            AccountingMonthResponse(
                month=row.month,
                income_cents=row.income_cents,
                total_income_cents=row.total_income_cents,
                income_by_kind=dict(row.income_by_kind),
                gross_cents=row.gross_cents,
                net_cents=row.net_cents,
                pupil_minutes=row.pupil_minutes,
                paid_minutes=row.paid_minutes,
                volunteer_minutes=row.volunteer_minutes,
                volunteer_value_cents=row.volunteer_value_cents,
            )
            for row in stats.months
        ],
        period_start=stats.period_start,
        period_end=stats.period_end,
        payers=stats.payers,
        volunteers=stats.volunteers,
        first_year=stats.first_year,
        income_per_hour_cents=stats.income_per_hour_cents,
        pay_per_hour_cents=stats.pay_per_hour_cents,
        lesson_cost_cents=stats.lesson_cost_cents,
        top_payers=[
            PayerItem(person=people[tax_code], cents=cents)
            for tax_code, cents in stats.top_payers
            if tax_code in people
        ],
        fee_pupils=[
            FeePupilItem(
                person=people[pupil.tax_code],
                fee_cents=pupil.fee_cents,
                months=pupil.months,
                paid_cents=pupil.paid_cents,
                minutes=pupil.minutes,
                cost_cents=pupil.cost_cents,
                even_minutes=pupil.even_minutes,
            )
            for pupil in stats.fee_pupils
            if pupil.tax_code in people
        ],
        break_even=[
            FeeBreakEvenItem(
                level=item.level.value,
                fee_cents=item.fee_cents,
                minutes=item.minutes,
            )
            for item in stats.break_even
        ],
    )
