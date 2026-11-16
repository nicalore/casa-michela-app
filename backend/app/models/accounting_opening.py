from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


# One row: money is worked out from money_from on; what came before is what the
# initial set-up says. Closed once every teacher and pupil listed is confirmed.
class AccountingOpening(Base):
    __tablename__ = "accounting_openings"

    __table_args__ = (CheckConstraint("id = 1", name="accounting_opening_single"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    money_from: Mapped[date] = mapped_column(Date, nullable=False)

    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    closed_by_tax_code: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )


# A teacher active when the set-up began: their pay of the days before money_from.
class TeacherOpening(Base):
    __tablename__ = "teacher_openings"

    __table_args__ = (
        CheckConstraint(
            "gross IS NULL OR gross >= 0",
            name="teacher_opening_gross_not_negative",
        ),
        CheckConstraint(
            "confirmed_at IS NOT NULL OR gross IS NULL",
            name="teacher_opening_gross_once_confirmed",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    # Null for a collaboration that is not paid.
    gross: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)

    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    confirmed_by_tax_code: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )


# A pupil active when the set-up began: how their account stood the day before
# money_from. The tariff and payments it wrote are ordinary rows; the minutes
# here are walked as lessons of that day.
class PupilOpening(Base):
    __tablename__ = "pupil_openings"

    __table_args__ = (
        CheckConstraint(
            "used_minutes >= 0 AND due_minutes >= 0 AND weekend_minutes >= 0",
            name="pupil_opening_minutes_not_negative",
        ),
        CheckConstraint(
            "used_minutes % 15 = 0 AND due_minutes % 15 = 0 "
            "AND weekend_minutes % 15 = 0",
            name="pupil_opening_minutes_by_quarter",
        ),
        CheckConstraint(
            "confirmed_at IS NOT NULL "
            "OR (used_minutes = 0 AND due_minutes = 0 AND weekend_minutes = 0)",
            name="pupil_opening_minutes_once_confirmed",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    # The tariff in force that day, written by the set-up.
    tariff_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("student_tariffs.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Minutes of the package in use already gone.
    used_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Hours to settle: by the hour, or beyond a package used up.
    due_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    weekend_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    confirmed_by_tax_code: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )
