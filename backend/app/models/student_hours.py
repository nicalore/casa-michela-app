from __future__ import annotations

from datetime import date, datetime, time

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
    Time,
    UniqueConstraint,
    false,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin


# A band whose pupils an admin has checked: payments read its hours, not the
# calendar. Apart from the teachers' confirmation of the same band.
class StudentConfirmedBand(CreatedAtMixin, Base):
    __tablename__ = "student_confirmed_bands"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="band_valid",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)
    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    confirmed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    confirmed_by_tax_code: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )

    # Opened again to be corrected: its hours still count until the next confirmation.
    reopened: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )


# Times only: payments must not hang on lessons that can be erased.
class StudentConfirmedHours(Base):
    __tablename__ = "student_confirmed_hours"

    __table_args__ = (
        ForeignKeyConstraint(
            ["date", "band"],
            ["student_confirmed_bands.date", "student_confirmed_bands.band"],
            ondelete="CASCADE",
        ),
        UniqueConstraint(
            "student_tax_code",
            "date",
            "start_time",
            name="unique_student_confirmed_hours",
        ),
        CheckConstraint(
            "end_time > start_time",
            name="end_after_start",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="mode_valid",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)
    band: Mapped[str] = mapped_column(String(20), nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    mode: Mapped[str] = mapped_column(String(20), nullable=False)


# What an admin wrote over the calendar for one pupil in one band.
# A row left alone follows the calendar; this one keeps its values.
class StudentHoursCorrection(UpdatedAtMixin, Base):
    __tablename__ = "student_hours_corrections"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="band_valid",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="mode_valid",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)
    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    # Not in the calendar: added by hand, gone when the correction goes.
    added: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )

    absent: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )

    # [["15:00", "18:30"], ...]; null follows the calendar.
    work: Mapped[list[list[str]] | None] = mapped_column(JSONB, nullable=True)
