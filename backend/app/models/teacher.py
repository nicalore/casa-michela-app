from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    ForeignKey,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.availability import Availability
    from app.models.staff import Staff
    from app.models.teacher_service import TeacherService
    from app.models.teaching_competence import TeachingCompetence


class Teacher(UpdatedAtMixin, Base):
    __tablename__ = "teachers"

    __table_args__ = (
        *not_blank_when_present_constraints(
            "school_education",
            "university_education",
        ),
        *no_surrounding_whitespace_constraints(
            "school_education",
            "university_education",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("staff.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    school_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    university_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    staff_member: Mapped[Staff] = relationship(
        back_populates="teacher_profile",
        uselist=False,
    )

    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

    teacher_services: Mapped[list[TeacherService]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

    availabilities: Mapped[list[Availability]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )
