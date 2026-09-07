from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.course_participant import CourseParticipant


# Catalogue of the courses the association runs. The name is a mutable natural
# key: course_participants points here with onupdate="CASCADE".
class Course(CreatedAtMixin, Base):
    __tablename__ = "courses"

    __table_args__ = (
        *not_blank_constraints("name"),
        *not_blank_when_present_constraints("description", "cost"),
        *no_surrounding_whitespace_constraints("name", "description", "cost"),
    )

    name: Mapped[str] = mapped_column(String(255), primary_key=True)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # Free text, not a number: it carries the period too ("45€ al mese").
    cost: Mapped[str | None] = mapped_column(String(100), nullable=True)

    participants: Mapped[list[CourseParticipant]] = relationship(
        back_populates="course",
    )
