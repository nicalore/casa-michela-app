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


# Who is answerable for a room, and between which hours. A room is watched over
# for as long as it is taught in, and one teacher rarely covers the whole
# stretch, so the shifts are several and have to join up without a gap. That
# they do is checked when the band is published, not here: the shifts are put
# together in whatever order suits, and a half-arranged day is not a broken one.
#
# There is no foreign key to teachers or to rooms, and none is missing. The
# single composite one below points at the assignment itself, which is what
# makes "the supervisor is a teacher assigned to that room" a fact the database
# holds rather than a rule the service remembers to check. Taking the assignment
# away takes the shifts with it, since a shift in a room the teacher no longer
# has is not a shift at all.
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
            # tax_code is a mutable natural key, and a teacher moved to another
            # room takes their own shifts along.
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
        # The service refuses overlapping shifts outright; this is the same rule
        # at the one point two racing requests cannot both win.
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

    # Plain columns and not foreign keys of their own: the key is the composite
    # one above, and declaring single-column ones as well would make three more
    # towards tables this one already reaches.
    teacher_tax_code: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        index=True,
    )

    room_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)
