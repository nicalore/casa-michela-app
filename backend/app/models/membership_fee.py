from __future__ import annotations

from datetime import date
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.member import PaymentMethodEnum
from app.models.mixins import CreatedAtMixin


class MembershipFeeKindEnum(StrEnum):
    MEMBERSHIP = "MEMBERSHIP"
    INSURANCE = "INSURANCE"


# A member's annual fee for a membership year; without a payment day it is owed.
class MembershipFee(CreatedAtMixin, Base):
    __tablename__ = "membership_fees"

    __table_args__ = (
        UniqueConstraint(
            "member_tax_code",
            "year",
            "kind",
            name="uq_membership_fee_member_year_kind",
        ),
        CheckConstraint(
            "amount_cents > 0",
            name="membership_fee_amount_positive",
        ),
        CheckConstraint(
            "(paid_on IS NULL) = (payment_method IS NULL)",
            name="membership_fee_paid_with_method",
        ),
        CheckConstraint(
            "payment_method_other IS NULL OR payment_method = 'OTHER'",
            name="membership_fee_other_requires_other_method",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    member_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("members.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    year: Mapped[int] = mapped_column(Integer, nullable=False)

    kind: Mapped[MembershipFeeKindEnum] = mapped_column(
        SqlEnum(MembershipFeeKindEnum, name="membership_fee_kind_enum"),
        nullable=False,
    )

    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)

    paid_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    payment_method: Mapped[PaymentMethodEnum | None] = mapped_column(
        SqlEnum(PaymentMethodEnum, name="payment_method_enum", create_type=False),
        nullable=True,
    )

    payment_method_other: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
