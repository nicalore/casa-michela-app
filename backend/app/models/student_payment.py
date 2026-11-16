from __future__ import annotations

from datetime import date
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.member import PaymentMethodEnum
from app.models.mixins import CreatedAtMixin


class StudentPaymentKindEnum(StrEnum):
    # A package bought: renewing is paying.
    PACKAGE = "PACKAGE"
    # A month's fee.
    MONTH = "MONTH"
    # Lessons settled by the hour.
    HOURS = "HOURS"
    # Hours paid before they are done, under an hourly tariff.
    AHEAD = "AHEAD"


# Which line of hours to settle a payment of hours came from.
class HoursKindEnum(StrEnum):
    HOURLY = "HOURLY"
    OVER_PACKAGE = "OVER_PACKAGE"
    OVER_FEE = "OVER_FEE"
    WEEKEND_ONLINE = "WEEKEND_ONLINE"


class StudentPayment(CreatedAtMixin, Base):
    __tablename__ = "student_payments"

    __table_args__ = (
        CheckConstraint(
            "amount_cents > 0",
            name="student_payment_amount_positive",
        ),
        CheckConstraint(
            "(kind = 'PACKAGE') = (package_hours IS NOT NULL)",
            name="student_payment_hours_only_for_packages",
        ),
        CheckConstraint(
            "package_hours IS NULL OR package_hours > 0",
            name="student_payment_package_hours_positive",
        ),
        CheckConstraint(
            "kind = 'HOURS' OR tariff_id IS NOT NULL",
            name="student_payment_package_or_month_has_tariff",
        ),
        CheckConstraint(
            "kind = 'MONTH' OR month IS NULL",
            name="student_payment_month_only_for_months",
        ),
        CheckConstraint(
            "(kind = 'HOURS') = (hours_kind IS NOT NULL)",
            name="student_payment_hours_kind_only_for_hours",
        ),
        CheckConstraint(
            "payment_method_other IS NULL OR payment_method = 'OTHER'",
            name="student_payment_other_requires_other_method",
        ),
        CheckConstraint(
            "(kind = 'AHEAD') = (ahead_minutes IS NOT NULL)",
            name="student_payment_ahead_minutes_only_for_ahead",
        ),
        CheckConstraint(
            "ahead_minutes IS NULL OR ahead_minutes > 0",
            name="student_payment_ahead_minutes_positive",
        ),
        CheckConstraint(
            "kind <> 'AHEAD' OR cents_per_hour IS NOT NULL",
            name="student_payment_ahead_has_rate",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    kind: Mapped[StudentPaymentKindEnum] = mapped_column(
        SqlEnum(StudentPaymentKindEnum, name="student_payment_kind_enum"),
        nullable=False,
    )

    # The package, monthly fee or hourly rate it was bought under.
    tariff_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("student_tariffs.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    # First day of the month paid; null for the first month of a fee that starts
    # when the package running now ends.
    month: Mapped[date | None] = mapped_column(Date, nullable=True)

    package_hours: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Hours paid ahead, by the quarter hour.
    ahead_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)

    hours_kind: Mapped[HoursKindEnum | None] = mapped_column(
        SqlEnum(HoursKindEnum, name="hours_kind_enum"),
        nullable=True,
    )

    cents_per_hour: Mapped[int | None] = mapped_column(Integer, nullable=True)

    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)

    paid_on: Mapped[date] = mapped_column(Date, nullable=False)

    payment_method: Mapped[PaymentMethodEnum] = mapped_column(
        SqlEnum(PaymentMethodEnum, name="payment_method_enum", create_type=False),
        nullable=False,
    )

    payment_method_other: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )


# The minutes of a pupil's confirmed band a payment of hours settled. By day and
# band, not by stretch: they hold when the band is confirmed again.
class StudentPaymentBand(Base):
    __tablename__ = "student_payment_bands"

    __table_args__ = (
        CheckConstraint(
            "minutes > 0",
            name="minutes_positive",
        ),
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="band_valid",
        ),
    )

    payment_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("student_payments.id", ondelete="CASCADE"),
        primary_key=True,
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)
    band: Mapped[str] = mapped_column(String(20), primary_key=True)
    minutes: Mapped[int] = mapped_column(Integer, nullable=False)
