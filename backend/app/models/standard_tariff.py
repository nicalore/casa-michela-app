from __future__ import annotations

from sqlalchemy import Boolean, CheckConstraint, Integer
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import UpdatedAtMixin
from app.models.study_program import EducationLevelEnum


# What a pupil of a level is offered for Aiuto Compiti; a kind turned off keeps
# its prices, and no pupil can be given it. The hourly rate also prices hours
# over a package or a fee, even while the hourly tariff is off.
class StandardTariff(UpdatedAtMixin, Base):
    __tablename__ = "standard_tariffs"

    __table_args__ = (
        CheckConstraint(
            "NOT package_enabled OR package_cents IS NOT NULL",
            name="standard_tariff_package_priced",
        ),
        CheckConstraint(
            "NOT monthly_enabled OR monthly_cents IS NOT NULL",
            name="standard_tariff_monthly_priced",
        ),
        CheckConstraint(
            "(package_cents IS NULL) = (package_hours IS NULL)",
            name="standard_tariff_package_hours",
        ),
        CheckConstraint(
            "hourly_enabled OR package_enabled OR monthly_enabled",
            name="standard_tariff_one_enabled",
        ),
        CheckConstraint(
            "hourly_cents > 0 "
            "AND (package_cents IS NULL OR package_cents > 0) "
            "AND (package_hours IS NULL OR package_hours > 0) "
            "AND (monthly_cents IS NULL OR monthly_cents > 0) "
            "AND weekend_online_cents > 0",
            name="standard_tariff_amounts_positive",
        ),
    )

    level: Mapped[EducationLevelEnum] = mapped_column(
        SqlEnum(EducationLevelEnum, name="education_level_enum", create_type=False),
        primary_key=True,
    )

    hourly_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)

    hourly_cents: Mapped[int] = mapped_column(Integer, nullable=False)

    package_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)

    package_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)

    package_hours: Mapped[int | None] = mapped_column(Integer, nullable=True)

    monthly_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)

    monthly_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Online on Saturday and Sunday, whatever the pupil's tariff.
    weekend_online_cents: Mapped[int] = mapped_column(Integer, nullable=False)


# The yearly membership fee and insurance: a single row, id 1.
class AnnualFees(UpdatedAtMixin, Base):
    __tablename__ = "annual_fees"

    __table_args__ = (
        CheckConstraint("id = 1", name="annual_fees_single_row"),
        CheckConstraint(
            "membership_cents > 0 AND insurance_cents > 0",
            name="annual_fees_positive",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    membership_cents: Mapped[int] = mapped_column(Integer, nullable=False)

    insurance_cents: Mapped[int] = mapped_column(Integer, nullable=False)
