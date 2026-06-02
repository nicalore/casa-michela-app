from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Index,
    Integer,
    String,
    text,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.teacher_subject import TeacherSubject
    from app.models.teaching_offering_subject import TeachingOfferingSubject


class Subject(Base):
    __tablename__ = "subjects"

    __table_args__ = (
        Index(
            "uq_subject_discipline_specialization",
            text("discipline"),
            text("COALESCE(specialization, '')"),
            unique=True,
        ),
        CheckConstraint(
            "length(trim(discipline)) > 0",
            name="discipline_not_blank",
        ),
        CheckConstraint(
            """
            specialization IS NULL
            OR length(trim(specialization)) > 0
            """,
            name="specialization_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "discipline",
            "specialization",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    discipline: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    specialization: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    teacher_subjects: Mapped[list[TeacherSubject]] = relationship(
        back_populates="subject",
        cascade="all, delete-orphan",
    )

    teaching_offering_subjects: Mapped[list[TeachingOfferingSubject]] = relationship(
        back_populates="subject",
        cascade="all, delete-orphan",
    )