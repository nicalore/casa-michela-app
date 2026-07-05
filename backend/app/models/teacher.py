from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.staff import Staff
    from app.models.teaching_competence import TeachingCompetence


class Teacher(Base):
    __tablename__ = "teachers"

    __table_args__ = (
        CheckConstraint(
            """
            school_education IS NULL
            OR length(trim(school_education)) > 0
            """,
            name="school_education_not_blank",
        ),
        CheckConstraint(
            """
            university_education IS NULL
            OR length(trim(university_education)) > 0
            """,
            name="university_education_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "school_education",
            "university_education",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "staff.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    school_education: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    university_education: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    # Colonna di concorrenza ottimistica per l'aggregato Teacher (discipline
    # insegnate). Stessa logica di Member.updated_at, applicata qui a
    # update_teacher_competences e al ramo docente di update_person.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    staff_member: Mapped[Staff] = relationship(
        back_populates="teacher_profile",
        uselist=False,
    )

    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )