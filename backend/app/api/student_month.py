from datetime import date
from typing import Annotated, Final

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.student_month import (
    StudentMonthResponse,
    StudentMonthRowResponse,
    StudentStandingResponse,
    TariffPartResponse,
)
from app.schemas.teacher_month import PendingBandResponse
from app.services import student_month
from app.services.student_month import StudentMonthRow, StudentMonthSummary

router = APIRouter(prefix="/accounting/student-month", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]
Year = Annotated[int, Path(ge=2000, le=2100)]
Month = Annotated[int, Path(ge=1, le=12)]

_FUTURE_MONTH_ERROR: Final[str] = "Il mese non è ancora iniziato"


def _month_or_400(year: int, month: int) -> date:
    first = date(year, month, 1)

    if first > now_in_rome().date().replace(day=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_FUTURE_MONTH_ERROR,
        )

    return first


def _row(row: StudentMonthRow) -> StudentMonthRowResponse:
    standing = row.standing

    return StudentMonthRowResponse(
        tax_code=row.tax_code,
        first_name=row.first_name,
        last_name=row.last_name,
        parts=[
            TariffPartResponse(
                tariff_kind=None if part.kind is None else part.kind.value,
                amount_cents=part.amount_cents,
                package_hours=part.package_hours,
                starts_on=part.starts_on,
                ends_on=part.ends_on,
                days=part.days,
                presence_days=part.presence_days,
                online_days=part.online_days,
                minutes=part.minutes,
                presence_minutes=part.presence_minutes,
                online_minutes=part.online_minutes,
            )
            for part in row.parts
        ],
        situation=(
            None
            if standing is None
            else StudentStandingResponse(
                kind=standing.kind,
                minutes=standing.minutes,
                due_cents=standing.due_cents,
                renewal=standing.renewal,
            )
        ),
    )


def _month(summary: StudentMonthSummary) -> StudentMonthResponse:
    return StudentMonthResponse(
        month=summary.month,
        rows=[_row(row) for row in summary.rows],
        pending=[
            PendingBandResponse(date=day, band=band) for day, band in summary.pending
        ],
        finished=summary.finished,
        situation_on=summary.standing_on,
        situation_shown=summary.standing_shown,
    )


@router.get("/{year}/{month}", response_model=StudentMonthResponse)
async def get_month(
    year: Year,
    month: Month,
    db: DbSession,
    _: Admin,
) -> StudentMonthResponse:
    summary = await student_month.month_summary(
        db,
        _month_or_400(year, month),
        now_in_rome(),
    )

    return _month(summary)
