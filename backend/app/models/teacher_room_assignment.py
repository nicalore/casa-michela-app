from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.room import Room


# Where a teacher works on a given day. Assigned once the lessons are settled
# and for the whole day, because that is how the association actually runs: a
# teacher takes a room in the afternoon and stays in it, teaching whoever is in
# front of them and whoever is on a screen out of the same seat.
#
# Only teachers who are in the building get one. Someone connecting from home
# occupies no room, and asking which one they are in has no answer.
#
# Both foreign keys restrict: this table is as much a record as the lessons
# are — who was in which room is exactly what has to be reconstructible months
# later — so neither the teacher nor the room can be deleted out from under it.
class TeacherRoomAssignment(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "teacher_room_assignments"

    __table_args__ = (
        # Trivially satisfied, since the first two columns are already the
        # primary key. It exists to be the target of the supervisions' composite
        # foreign key: Postgres wants a UNIQUE on exactly the columns referenced.
        UniqueConstraint(
            "date",
            "teacher_tax_code",
            "room_id",
            name="uq_teacher_room_identity",
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

    room_id: Mapped[int] = mapped_column(
        ForeignKey("rooms.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    room: Mapped[Room] = relationship()
