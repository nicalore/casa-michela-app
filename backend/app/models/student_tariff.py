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
from app.models.mixins import CreatedAtMixin


class TariffKindEnum(StrEnum):
    HOURLY = "HOURLY"
    PACKAGE = "PACKAGE"
    MONTHLY = "MONTHLY"


# How a pupil pays for Aiuto Compiti from a day on, until the next row; rows of
# one day follow their ids. A row after a package starts once its hours are used.
# Packages and months are bought as payments.
class StudentTariff(CreatedAtMixin, Base):
    __tablename__ = "student_tariffs"

    __table_args__ = (
        CheckConstraint(
            "amount_cents > 0",
            name="student_tariff_amount_positive",
        ),
        CheckConstraint(
            "(kind = 'PACKAGE') = (package_hours IS NOT NULL)",
            name="student_tariff_hours_only_for_packages",
        ),
        CheckConstraint(
            "package_hours IS NULL OR package_hours > 0",
            name="student_tariff_hours_positive",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    kind: Mapped[TariffKindEnum] = mapped_column(
        SqlEnum(TariffKindEnum, name="tariff_kind_enum"),
        nullable=False,
    )

    starts_on: Mapped[date] = mapped_column(Date, nullable=False)

    # Per hour, per package or per month, as the kind says; for packages and
    # months, what the first one costs.
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)

    package_hours: Mapped[int | None] = mapped_column(Integer, nullable=True)
