from collections.abc import Callable
from datetime import date, time
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.accounting_stats import (
    AccountingMonthResponse,
    AccountingStatsResponse,
)
from app.services.accounting_stats import WINDOW_MONTHS, accounting_stats

router = APIRouter(prefix="/accounting/statistics", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


def _is_over() -> Callable[[date, time], bool]:
    now = now_in_rome()

    def over(day: date, end_time: time) -> bool:
        return day < now.date() or (day == now.date() and end_time <= now.time())

    return over


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
    )
