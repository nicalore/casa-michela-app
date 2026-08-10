from __future__ import annotations

from sqlalchemy import CheckConstraint, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin


# A place in the building, which is why only teaching done in the building needs
# one. A room is not held by a lesson but assigned to a teacher for a day, and
# more than one teacher shares it — that is how a study hall works. So what a
# room constrains is not who is in it but how many people fit.
#
# capacity is null wherever nobody has counted, and null is not zero: an
# unmeasured room holds as many as it holds, and the calendar warns instead of
# refusing rather than enforce a number no one has checked.
class Room(CreatedAtMixin, Base):
    __tablename__ = "rooms"

    __table_args__ = (
        UniqueConstraint("name", name="uq_room_name"),
        CheckConstraint("id > 0", name="positive_room_id"),
        CheckConstraint(
            "capacity IS NULL OR capacity > 0",
            name="room_capacity_positive",
        ),
        *not_blank_constraints("name"),
        *not_blank_when_present_constraints("description"),
        *no_surrounding_whitespace_constraints("name", "description"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    capacity: Mapped[int | None] = mapped_column(Integer, nullable=True)
