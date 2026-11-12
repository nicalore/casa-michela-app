from datetime import date
from typing import Annotated, Final

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.models.student import Student
from app.schemas.booking_history import BookingHistoryMonthResponse
from app.services.booking_history import booked_months, month_history

router = APIRouter(prefix="/people", tags=["booking-history"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]

_STUDENT_NOT_FOUND_ERROR: Final[str] = "Studente non trovato"
_FUTURE_MONTH_ERROR: Final[str] = "Il mese non è ancora iniziato"


async def _student_or_404(db: AsyncSession, tax_code: str) -> str:
    code = tax_code.upper()

    if await db.get(Student, code) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_STUDENT_NOT_FOUND_ERROR,
        )

    return code


@router.get(
    "/{tax_code}/bookings-history",
    response_model=BookingHistoryMonthResponse,
)
async def booking_history(
    tax_code: str,
    db: DbSession,
    _: Admin,
    year: int = Query(..., ge=1),
    month: int = Query(..., ge=1, le=12),
) -> BookingHistoryMonthResponse:
    code = await _student_or_404(db, tax_code)
    today = now_in_rome().date()
    first = date(year, month, 1)

    if first > today.replace(day=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_FUTURE_MONTH_ERROR,
        )

    return await month_history(db, code, first, today)


@router.get("/{tax_code}/bookings-history/months", response_model=list[date])
async def booking_history_months(
    tax_code: str,
    db: DbSession,
    _: Admin,
) -> list[date]:
    code = await _student_or_404(db, tax_code)

    return await booked_months(db, code, now_in_rome().date())
