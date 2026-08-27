from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.room import Room


# One room per teacher for the whole day; only in-building teachers get one.
# Both FKs RESTRICT: who was in which room must stay reconstructible later.
class TeacherRoomAssignment(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "teacher_room_assignments"

    __table_args__ = (
        # Trivially satisfied (the columns are the PK); exists only because the
        # supervisions' composite FK needs a UNIQUE on the referenced columns.
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
