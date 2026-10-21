from __future__ import annotations

from datetime import date, time
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, ForeignKey, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.room import Room

MIDNIGHT = time(0, 0)


# From start_time until the teacher's next row; the first row starts at midnight.
# Both FKs RESTRICT: who was in which room must stay reconstructible later.
class TeacherRoomAssignment(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "teacher_room_assignments"

    __table_args__ = (
        # Trivially satisfied (it holds the PK); exists only because the
        # supervisions' composite FK needs a UNIQUE on the referenced columns.
        UniqueConstraint(
            "date",
            "teacher_tax_code",
            "start_time",
            "room_id",
            name="uq_teacher_room_stretch",
        ),
        CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0",
            name="teacher_room_assignment_time_step",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey(
            "teachers.tax_code",
            ondelete="RESTRICT",
            onupdate="CASCADE",
        ),
        primary_key=True,
    )

    start_time: Mapped[time] = mapped_column(
        Time,
        primary_key=True,
        default=MIDNIGHT,
    )

    room_id: Mapped[int] = mapped_column(
        ForeignKey("rooms.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    room: Mapped[Room] = relationship()
