from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import Final

from sqlalchemy import CheckConstraint, Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

_RULE_VALID: Final[str] = "rule IN ('weekly', 'daily', 'none')"


# How a paid teacher's unpaid hour is counted.
class VolunteeringRule(StrEnum):
    WEEKLY = "weekly"
    DAILY = "daily"
    NONE = "none"


# A teacher's rule from a month on, until the next row. No rows: one hour a week.
class VolunteeringRuleChange(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "volunteering_rules"

    __table_args__ = (
        CheckConstraint(
            "EXTRACT(DAY FROM starts_on) = 1",
            name="volunteering_rule_starts_a_month",
        ),
        CheckConstraint(_RULE_VALID, name="volunteering_rule_valid"),
    )

    staff_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    starts_on: Mapped[date] = mapped_column(Date, primary_key=True)

    rule: Mapped[str] = mapped_column(String(10), nullable=False)


# One month counted otherwise than the teacher's rule, chosen in the monthly
# summary for that month alone.
class VolunteeringMonth(CreatedAtMixin, Base):
    __tablename__ = "volunteering_months"

    __table_args__ = (
        CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="volunteering_month_first_day",
        ),
        CheckConstraint(_RULE_VALID, name="volunteering_month_rule_valid"),
    )

    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    month: Mapped[date] = mapped_column(Date, primary_key=True)

    rule: Mapped[str] = mapped_column(String(10), nullable=False)
