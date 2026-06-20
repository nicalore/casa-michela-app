from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.school import School
    from app.models.school_enrollment import SchoolEnrollment
    from app.models.study_program import StudyProgram


class SchoolStudyProgram(Base):
    __tablename__ = "school_study_programs"

    __table_args__ = (
        *no_surrounding_whitespace_constraints(
            "school_mechanographic_code",
        ),
    )

    study_program_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "study_programs.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    school_mechanographic_code: Mapped[str] = mapped_column(
        String(20), 
        ForeignKey(
            "schools.mechanographic_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    study_program: Mapped[StudyProgram] = relationship(
        back_populates="school_study_programs",
    )

    school: Mapped[School] = relationship(
        back_populates="school_study_programs",
    )

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="school_study_program",
        cascade="all, delete-orphan",
    )