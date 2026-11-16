from dataclasses import dataclass
from datetime import date, datetime
from typing import Final

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.member import PaymentMethodEnum
from app.models.membership_fee import MembershipFee, MembershipFeeKindEnum
from app.models.person import Person
from app.models.student_payment import (
    StudentPayment,
    StudentPaymentBand,
    StudentPaymentKindEnum,
)
from app.services.member_roles import roles_of
from app.services.worked_hours import month_after

_FEE_KINDS: Final[dict[MembershipFeeKindEnum, str]] = {
    MembershipFeeKindEnum.MEMBERSHIP: "MEMBERSHIP_FEE",
    MembershipFeeKindEnum.INSURANCE: "INSURANCE_FEE",
}


@dataclass
class MonthPayment:
    paid_on: date
    created_at: datetime
    tax_code: str
    kind: str
    amount_cents: int
    payment_method: PaymentMethodEnum | None
    payment_method_other: str | None
    package_hours: int | None = None
    month: date | None = None
    ahead_minutes: int | None = None
    minutes: int | None = None
    year: int | None = None
    first_name: str = ""
    last_name: str = ""
    roles: tuple[str, ...] = ()


def _kind(payment: StudentPayment) -> str:
    if payment.kind == StudentPaymentKindEnum.HOURS and payment.hours_kind:
        return payment.hours_kind.value

    return payment.kind.value


async def month_payments(db: AsyncSession, month: date) -> list[MonthPayment]:
    """Everything paid in the month by anyone, the newest first."""
    end = month_after(month)
    payments = list(
        await db.scalars(
            select(StudentPayment).where(
                StudentPayment.paid_on >= month,
                StudentPayment.paid_on < end,
            ),
        )
    )
    totals = await db.execute(
        select(StudentPaymentBand.payment_id, func.sum(StudentPaymentBand.minutes))
        .where(StudentPaymentBand.payment_id.in_([item.id for item in payments]))
        .group_by(StudentPaymentBand.payment_id),
    )
    settled: dict[int, int] = {
        payment_id: int(minutes) for payment_id, minutes in totals.tuples()
    }
    fees = await db.scalars(
        select(MembershipFee).where(
            MembershipFee.paid_on >= month,
            MembershipFee.paid_on < end,
        ),
    )

    rows = [
        MonthPayment(
            paid_on=payment.paid_on,
            created_at=payment.created_at,
            tax_code=payment.student_tax_code,
            kind=_kind(payment),
            amount_cents=payment.amount_cents,
            payment_method=payment.payment_method,
            payment_method_other=payment.payment_method_other,
            package_hours=payment.package_hours,
            month=payment.month,
            ahead_minutes=payment.ahead_minutes,
            minutes=(
                settled.get(payment.id)
                if payment.kind == StudentPaymentKindEnum.HOURS
                else None
            ),
        )
        for payment in payments
    ]

    for fee in fees:
        if fee.paid_on is None:
            continue

        rows.append(
            MonthPayment(
                paid_on=fee.paid_on,
                created_at=fee.created_at,
                tax_code=fee.member_tax_code,
                kind=_FEE_KINDS[fee.kind],
                amount_cents=fee.amount_cents,
                payment_method=fee.payment_method,
                payment_method_other=fee.payment_method_other,
                year=fee.year,
            )
        )

    codes = {row.tax_code for row in rows}

    if not codes:
        return []

    names = {
        tax_code: (first, last)
        for tax_code, first, last in (
            await db.execute(
                select(Person.tax_code, Person.first_name, Person.last_name).where(
                    Person.tax_code.in_(codes),
                ),
            )
        ).tuples()
    }
    roles = await roles_of(db, codes)

    for row in rows:
        row.first_name, row.last_name = names.get(row.tax_code, ("", ""))
        row.roles = roles[row.tax_code]

    return sorted(
        rows,
        key=lambda row: (row.paid_on, row.created_at),
        reverse=True,
    )
