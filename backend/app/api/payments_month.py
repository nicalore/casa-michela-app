from datetime import date
from typing import Annotated, Final

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.payments_month import MonthPaymentResponse, PaymentsMonthResponse
from app.services.payments_month import month_payments

router = APIRouter(prefix="/accounting/payments", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]
Year = Annotated[int, Path(ge=2000, le=2100)]
Month = Annotated[int, Path(ge=1, le=12)]

_FUTURE_MONTH_ERROR: Final[str] = "Il mese non è ancora iniziato"


# Every payment of the month, from anyone: hours, packages, fees.
@router.get("/{year}/{month}", response_model=PaymentsMonthResponse)
async def get_month_payments(
    year: Year,
    month: Month,
    db: DbSession,
    _: Admin,
) -> PaymentsMonthResponse:
    first = date(year, month, 1)

    if first > now_in_rome().date().replace(day=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_FUTURE_MONTH_ERROR,
        )

    rows = await month_payments(db, first)

    return PaymentsMonthResponse(
        month=first,
        total_cents=sum(row.amount_cents for row in rows),
        rows=[
            MonthPaymentResponse.model_validate(
                {
                    "paid_on": row.paid_on,
                    "tax_code": row.tax_code,
                    "first_name": row.first_name,
                    "last_name": row.last_name,
                    "roles": list(row.roles),
                    "kind": row.kind,
                    "amount_cents": row.amount_cents,
                    "payment_method": row.payment_method,
                    "payment_method_other": row.payment_method_other,
                    "package_hours": row.package_hours,
                    "month": row.month,
                    "ahead_minutes": row.ahead_minutes,
                    "minutes": row.minutes,
                    "year": row.year,
                }
            )
            for row in rows
        ],
    )
