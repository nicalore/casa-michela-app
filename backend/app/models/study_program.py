from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy import (
    Enum as SqlEnum,
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
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.study_program_subject import StudyProgramSubject
    from app.models.teaching_competence import TeachingCompetence


class EducationLevelEnum(StrEnum):
    PRIMARY_SCHOOL = "PRIMARY_SCHOOL"
    MIDDLE_SCHOOL = "MIDDLE_SCHOOL"
    HIGH_SCHOOL = "HIGH_SCHOOL"


class StudyProgram(Base):
    __tablename__ = "study_programs"

    __table_args__ = (
        UniqueConstraint(
            "level",
            "name",
            name="uq_level_program_name",
        ),
        CheckConstraint(
            "id > 0",
            name="positive_study_program_id",
        ),
        CheckConstraint(
            "length(trim(name)) > 0",
            name="study_program_name_not_blank",
        ),
        CheckConstraint(
            """
            description IS NULL
            OR length(trim(description)) > 0
            """,
            name="study_program_description_not_blank",
        ),
        CheckConstraint(
            "min_year >= 1",
            name="study_program_min_year_valid",
        ),
        CheckConstraint(
            "min_year <= max_year",
            name="study_program_years_range_valid",
        ),
        CheckConstraint(
            """
            (level = 'PRIMARY_SCHOOL' AND max_year <= 5) OR
            (level = 'MIDDLE_SCHOOL' AND max_year <= 3) OR
            (level = 'HIGH_SCHOOL' AND max_year <= 5)
            """,
            name="study_program_level_max_year_match",
        ),
        *no_surrounding_whitespace_constraints(
            "name",
            "description",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    level: Mapped[EducationLevelEnum] = mapped_column(
        SqlEnum(
            EducationLevelEnum,
            name="education_level_enum",
        ),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        String(1000),
        nullable=True,
    )

    min_year: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    max_year: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    school_study_programs: Mapped[list[SchoolStudyProgram]] = relationship(
        back_populates="study_program",
        cascade="all, delete-orphan",
    )

    study_program_subjects: Mapped[list[StudyProgramSubject]] = relationship(
        back_populates="study_program",
        cascade="all, delete-orphan",
    )

    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        back_populates="study_program",
        cascade="all, delete-orphan",
    )

    ministry_subjects = relationship(
        "MinistrySubject",
        secondary="study_program_subjects",
        backref="study_programs"
    )

    schools: Mapped[list[School]] = relationship(
        "School",
        secondary="school_study_programs",
        viewonly=True
    )