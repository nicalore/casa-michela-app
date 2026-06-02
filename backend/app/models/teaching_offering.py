from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import Enum as SqlEnum
from sqlalchemy import (
    ForeignKey,
    Integer,
    UniqueConstraint,
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
    from app.models.teacher_offering import TeacherOffering
    from app.models.teaching_offering_subject import TeachingOfferingSubject
    from app.models.teaching_offering_year import TeachingOfferingYear


class EducationLevelEnum(StrEnum):
    PRIMARY_SCHOOL = "PRIMARY_SCHOOL"
    MIDDLE_SCHOOL = "MIDDLE_SCHOOL"
    HIGH_SCHOOL = "HIGH_SCHOOL"


class TeachingOffering(Base):
    __tablename__ = "teaching_offerings"

    __table_args__ = (
        UniqueConstraint(
            "school_mechanographic_code",
            "study_program_id",
            "level",
            name="uq_teaching_offering",
        ),
        *no_surrounding_whitespace_constraints(
            "school_mechanographic_code",
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

    school_mechanographic_code: Mapped[str] = mapped_column(
        ForeignKey(
            "schools.mechanographic_code",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    study_program_id: Mapped[int] = mapped_column(
        ForeignKey(
            "study_programs.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    teacher_offerings: Mapped[list[TeacherOffering]] = relationship(
        back_populates="teaching_offering",
        cascade="all, delete-orphan",
    )

    teaching_offering_subjects: Mapped[list[TeachingOfferingSubject]] = relationship(
        back_populates="teaching_offering",
        cascade="all, delete-orphan",
    )

    years: Mapped[list[TeachingOfferingYear]] = relationship(
        back_populates="teaching_offering",
        cascade="all, delete-orphan",
    )

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="teaching_offering",
    )

    school: Mapped[School] = relationship(
        back_populates="teaching_offerings",
    )

    study_program: Mapped[StudyProgram] = relationship(
        back_populates="teaching_offerings",
    )