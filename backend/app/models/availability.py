from __future__ import annotations

from datetime import date, time
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Integer,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.calendar_activity import CalendarActivity
    from app.models.lesson import Lesson
    from app.models.teacher import Teacher


class Availability(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "availabilities"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_availability_id"),
        CheckConstraint("end_time > start_time", name="availability_end_after_start"),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="availability_mode_valid",
        ),
        CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name="availability_time_step",
        ),
        # Backstop for the service's overlap check against racing requests.
        Index(
            "ux_availability_slot",
            "teacher_tax_code",
            "date",
            "mode",
            "start_time",
            unique=True,
        ),
        # Trivially satisfied; exists only as the target of the lessons'
        # composite FK, which Postgres requires a matching UNIQUE for.
        UniqueConstraint("id", "date", "mode", name="uq_availability_identity"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    teacher: Mapped[Teacher] = relationship(back_populates="availabilities")

    # No cascade on purpose: on delete the ORM must leave lessons alone so the
    # database RESTRICT refuses; loading them would also lazy-load under async.
    lessons: Mapped[list[Lesson]] = relationship(
        back_populates="availability",
        passive_deletes="all",
    )

    # Same reasoning as lessons above.
    activities: Mapped[list[CalendarActivity]] = relationship(
        back_populates="availability",
        passive_deletes="all",
    )
