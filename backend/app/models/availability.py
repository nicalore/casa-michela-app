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
        # A teacher's day in one mode is made of stretches that begin at
        # different times. The service refuses overlapping ones outright; this
        # is the same rule at the one point two racing requests cannot both win.
        Index(
            "ux_availability_slot",
            "teacher_tax_code",
            "date",
            "mode",
            "start_time",
            unique=True,
        ),
        # Trivially satisfied, since id is already the primary key. It exists to
        # be the target of the lessons' composite foreign key: Postgres wants a
        # UNIQUE on exactly the columns referenced, and that key is what stops a
        # lesson's own date and mode from ever drifting from this row's.
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

    # Being there and being online are two different offers, kept apart the way
    # the association's own opening hours are: a teacher can be in the building
    # in the morning and at a screen in the evening, and the two are booked
    # against different opening hours.
    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    teacher: Mapped[Teacher] = relationship(back_populates="availabilities")

    # passive_deletes="all" and deliberately not a cascade: when an availability
    # is deleted the ORM must not touch the lessons at all, neither removing
    # them nor blanking their foreign key, because the right answer is for the
    # database to refuse. Loading the collection to find that out would also be
    # a lazy load inside AvailabilityService.delete, which under async raises.
    lessons: Mapped[list[Lesson]] = relationship(
        back_populates="availability",
        passive_deletes="all",
    )
