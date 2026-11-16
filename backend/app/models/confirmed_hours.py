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


# A band an admin has checked: ConfirmedHours speak for it, not the calendar.
class ConfirmedBand(CreatedAtMixin, Base):
    __tablename__ = "confirmed_bands"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="confirmed_band_valid",
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

    # Opened again to be corrected: its hours still pay until the next confirmation.
    reopened: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )


# Times only: pay must not hang on lessons or pupils that can be erased.
class ConfirmedHours(Base):
    __tablename__ = "confirmed_hours"

    __table_args__ = (
        ForeignKeyConstraint(
            ["date", "band"],
            ["confirmed_bands.date", "confirmed_bands.band"],
            ondelete="CASCADE",
        ),
        UniqueConstraint(
            "teacher_tax_code",
            "date",
            "start_time",
            name="unique_confirmed_hours",
        ),
        CheckConstraint(
            "end_time > start_time",
            name="confirmed_hours_end_after_start",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="confirmed_hours_mode_valid",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)
    band: Mapped[str] = mapped_column(String(20), nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    # In person the stretches may be several, written by hand: the count says nothing.
    mode: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        server_default="presence",
    )


# Volunteering an admin wrote by hand: the rule no longer decides that band.
# No times is none at all. Bands without a row follow the month's rule.
class ConfirmedVolunteering(Base):
    __tablename__ = "confirmed_volunteering"

    __table_args__ = (
        ForeignKeyConstraint(
            ["date", "band"],
            ["confirmed_bands.date", "confirmed_bands.band"],
            ondelete="CASCADE",
        ),
        UniqueConstraint(
            "teacher_tax_code",
            "date",
            "band",
            name="unique_confirmed_volunteering",
        ),
        CheckConstraint(
            "(start_time IS NULL) = (end_time IS NULL)",
            name="confirmed_volunteering_whole",
        ),
        # Null times leave it unknown, so none at all passes too.
        CheckConstraint(
            "end_time > start_time",
            name="confirmed_volunteering_end_after_start",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)
    band: Mapped[str] = mapped_column(String(20), nullable=False)
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    end_time: Mapped[time | None] = mapped_column(Time, nullable=True)


# What an admin wrote over the calendar for one teacher in one band.
# A row left alone follows the calendar; this one keeps its values.
class HoursCorrection(UpdatedAtMixin, Base):
    __tablename__ = "hours_corrections"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="hours_correction_band_valid",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="hours_correction_mode_valid",
        ),
        CheckConstraint(
            "(volunteer_start IS NULL) = (volunteer_end IS NULL)",
            name="hours_correction_volunteer_whole",
        ),
        CheckConstraint(
            "volunteer_end IS NULL OR volunteer_end > volunteer_start",
            name="hours_correction_volunteer_end_after_start",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)
    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
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

    # False leaves the volunteering to the weekly rule; true with no times is none.
    volunteer_set: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=false(),
    )

    volunteer_start: Mapped[time | None] = mapped_column(Time, nullable=True)
    volunteer_end: Mapped[time | None] = mapped_column(Time, nullable=True)
