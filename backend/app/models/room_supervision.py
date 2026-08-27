from __future__ import annotations

from datetime import date, time

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Time,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin


# Gap coverage is checked at publication, not here. No FKs to teachers or
# rooms on purpose: the composite FK to the assignment makes "supervisor is
# assigned to that room" a DB fact, and deleting the assignment cascades here.
class RoomSupervision(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "room_supervisions"

    __table_args__ = (
        ForeignKeyConstraint(
            ["date", "teacher_tax_code", "room_id"],
            [
                "teacher_room_assignments.date",
                "teacher_room_assignments.teacher_tax_code",
                "teacher_room_assignments.room_id",
            ],
            ondelete="CASCADE",
            # tax_code is a mutable natural key; a moved teacher keeps their shifts.
            onupdate="CASCADE",
            name="room_supervisions_assignment_fkey",
        ),
        CheckConstraint("id > 0", name="positive_room_supervision_id"),
        CheckConstraint(
            "end_time > start_time",
            name="room_supervision_end_after_start",
        ),
        CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name="room_supervision_time_step",
        ),
        # Same overlap rule the service enforces, held where races cannot both win.
        Index(
            "ux_room_supervision_slot",
            "date",
            "room_id",
            "teacher_tax_code",
            "start_time",
            unique=True,
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    date: Mapped[date] = mapped_column(Date, nullable=False)

    # Plain columns: the composite FK above is the only key needed.
    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        index=True,
    )

    room_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)
