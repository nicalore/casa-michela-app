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
    from app.models.teacher_service import TeacherService


# Something the association offers besides a school subject: asked for the same
# way a subject is, but with no ministry subject behind it and no syllabus,
# which is why it is a catalogue of its own. The name is a mutable natural key,
# so any foreign key pointing here needs onupdate="CASCADE", as tax_code does.
class Service(CreatedAtMixin, Base):
    __tablename__ = "services"

    __table_args__ = (
        *not_blank_constraints("name"),
        *not_blank_when_present_constraints("description"),
        *no_surrounding_whitespace_constraints("name", "description"),
    )

    name: Mapped[str] = mapped_column(String(255), primary_key=True)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    teacher_services: Mapped[list[TeacherService]] = relationship(
        back_populates="service",
        cascade="all, delete-orphan",
    )
