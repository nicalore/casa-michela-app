from collections.abc import Sequence
from datetime import date, timedelta
from typing import Final, Protocol

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.member import PaymentMethodEnum
from app.models.membership_fee import MembershipFee, MembershipFeeKindEnum
from app.schemas.membership_fees import WizardFeesData
from app.schemas.student_payments import PaymentData

_FEE_NOT_FOUND_ERROR: Final[str] = "Quota non trovata."
_FEE_PAID_ERROR: Final[str] = "Questa quota è già pagata."
_FEE_NOT_PAID_ERROR: Final[str] = "Questa quota non è pagata."
_PAID_IN_FUTURE_ERROR: Final[str] = "La data del pagamento è nel futuro."

# The order the history and the wizard list them in.
FEE_KINDS: Final[tuple[MembershipFeeKindEnum, ...]] = (
    MembershipFeeKindEnum.MEMBERSHIP,
    MembershipFeeKindEnum.INSURANCE,
)


class _Membership(Protocol):
    @property
    def year(self) -> int: ...

    @property
    def end_date(self) -> date: ...

    @property
    def renewal_period_days(self) -> int: ...


# The register's rule on rows not saved yet: the newest one, still in its window.
def enrolled_year(memberships: Sequence[_Membership], today: date) -> int | None:
    if not memberships:
        return None

    latest = max(memberships, key=lambda row: row.year)
    lapses_on = latest.end_date + timedelta(days=latest.renewal_period_days)

    return latest.year if lapses_on > today else None


def first_fees(
    tax_code: str,
    year: int,
    data: WizardFeesData,
    method: PaymentMethodEnum,
    method_other: str | None,
    today: date,
) -> list[MembershipFee]:
    """A new member's fees of the year: paid today with their method, or owed."""
    fees: list[MembershipFee] = []

    for kind, fee in (
        (MembershipFeeKindEnum.MEMBERSHIP, data.membership),
        (MembershipFeeKindEnum.INSURANCE, data.insurance),
    ):
        fees.append(
            MembershipFee(
                member_tax_code=tax_code,
                year=year,
                kind=kind,
                amount_cents=fee.amount_cents,
                paid_on=today if fee.paid else None,
                payment_method=method if fee.paid else None,
                payment_method_other=(
                    method_other
                    if fee.paid and method == PaymentMethodEnum.OTHER
                    else None
                ),
            )
        )

    return fees


async def member_fees(db: AsyncSession, tax_code: str) -> list[MembershipFee]:
    rows = await db.scalars(
        select(MembershipFee).where(MembershipFee.member_tax_code == tax_code),
    )

    return sorted(rows, key=lambda row: (row.year, FEE_KINDS.index(row.kind)))


async def _fee_of(db: AsyncSession, tax_code: str, fee_id: int) -> MembershipFee:
    fee = await db.get(MembershipFee, fee_id)

    if fee is None or fee.member_tax_code != tax_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_FEE_NOT_FOUND_ERROR,
        )

    return fee


async def settle_fee(
    db: AsyncSession,
    tax_code: str,
    fee_id: int,
    data: PaymentData,
    today: date,
) -> MembershipFee:
    fee = await _fee_of(db, tax_code, fee_id)

    if fee.paid_on is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_FEE_PAID_ERROR,
        )

    if data.paid_on > today:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_PAID_IN_FUTURE_ERROR,
        )

    fee.paid_on = data.paid_on
    fee.payment_method = data.payment_method
    fee.payment_method_other = (
        data.payment_method_other
        if data.payment_method == PaymentMethodEnum.OTHER
        else None
    )
    await db.flush()

    return fee


# A fee paid by mistake: owed again.
async def cancel_fee_payment(
    db: AsyncSession,
    tax_code: str,
    fee_id: int,
) -> MembershipFee:
    fee = await _fee_of(db, tax_code, fee_id)

    if fee.paid_on is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_FEE_NOT_PAID_ERROR,
        )

    fee.paid_on = None
    fee.payment_method = None
    fee.payment_method_other = None
    await db.flush()

    return fee
