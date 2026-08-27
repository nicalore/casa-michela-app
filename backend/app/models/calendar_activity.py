from __future__ import annotations

from datetime import date, time
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Time,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.availability import Availability

# The assignment columns, written together or not at all; the check below and
# the service both depend on this exact list.
_ASSIGNMENT: Final[tuple[str, ...]] = (
    "availability_id",
    "teacher_mode",
    "start_time",
    "end_time",
)

_UNASSIGNED: Final[str] = " AND ".join(f"{column} IS NULL" for column in _ASSIGNMENT)

_ASSIGNED: Final[str] = " AND ".join(f"{column} IS NOT NULL" for column in _ASSIGNMENT)

# Must stay in sync with the bounds in app/core/time_band.py.
_WITHIN_BAND: Final[str] = (
    "start_time IS NULL "
    "OR (band = 'MORNING' AND start_time >= TIME '06:00' "
    "AND end_time <= TIME '13:00') "
    "OR (band = 'AFTERNOON' AND start_time >= TIME '13:00' "
    "AND end_time <= TIME '19:00') "
    "OR (band = 'EVENING' AND start_time >= TIME '19:00' "
    "AND end_time <= TIME '23:00')"
)


# band is stored, not computed: an activity may exist before it has any times.
# The four nullable assignment columns are all-or-nothing (checked below).
class CalendarActivity(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "calendar_activities"

    __table_args__ = (
        ForeignKeyConstraint(
            ["availability_id", "date", "teacher_mode"],
            [
                "availabilities.id",
                "availabilities.date",
                "availabilities.mode",
            ],
            ondelete="RESTRICT",
            name="calendar_activities_availability_fkey",
        ),
        CheckConstraint("id > 0", name="positive_calendar_activity_id"),
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_activity_band_valid",
        ),
        CheckConstraint(
            "teacher_mode IS NULL OR teacher_mode IN ('presence', 'online')",
            name="calendar_activity_teacher_mode_valid",
        ),
        CheckConstraint(
            f"({_UNASSIGNED}) OR ({_ASSIGNED})",
            name="calendar_activity_assignment_whole",
        ),
        # Null-safe: with either end missing the comparison is null, not false.
        CheckConstraint(
            "end_time > start_time",
            name="calendar_activity_end_after_start",
        ),
        CheckConstraint(
            "start_time IS NULL "
            "OR (EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0)",
            name="calendar_activity_time_step",
        ),
        CheckConstraint(_WITHIN_BAND, name="calendar_activity_within_band"),
        *not_blank_constraints("name"),
        *not_blank_when_present_constraints("description"),
        *no_surrounding_whitespace_constraints("name", "description"),
        Index("ix_calendar_activity_day", "date", "band"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    date: Mapped[date] = mapped_column(Date, nullable=False)

    band: Mapped[str] = mapped_column(String(20), nullable=False)

    # Deliberately not unique: duplicate names in one calendar are legitimate.
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # Plain Integer: the FK is the composite one above.
    availability_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True,
    )

    teacher_mode: Mapped[str | None] = mapped_column(String(20), nullable=True)

    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)

    end_time: Mapped[time | None] = mapped_column(Time, nullable=True)

    availability: Mapped[Availability | None] = relationship(
        back_populates="activities",
    )

    @property
    def is_assigned(self) -> bool:
        return self.availability_id is not None
