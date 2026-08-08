from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Index,
    Integer,
    String,
    text,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, backref, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.school import School
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.study_program_subject import StudyProgramSubject
    from app.models.teaching_competence import TeachingCompetence


class EducationLevelEnum(StrEnum):
    PRIMARY_SCHOOL = "PRIMARY_SCHOOL"
    MIDDLE_SCHOOL = "MIDDLE_SCHOOL"
    HIGH_SCHOOL = "HIGH_SCHOOL"


class StudyProgram(CreatedAtMixin, Base):
    __tablename__ = "study_programs"

    __table_args__ = (
        # The sector is part of a programme's identity: the same name exists
        # under two different sectors, and with the sector out of the name the
        # two would collapse into one row.
        #
        # coalesce rather than the bare column because primary and middle school
        # have no sector: with NULL, Postgres treats even two otherwise
        # identical rows as distinct, and the constraint would say nothing.
        Index(
            "uq_level_sector_program_name",
            "level",
            text("coalesce(sector, '')"),
            "name",
            unique=True,
        ),
        CheckConstraint("id > 0", name="positive_study_program_id"),
        CheckConstraint("length(trim(name)) > 0", name="study_program_name_not_blank"),
        CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name="study_program_description_not_blank",
        ),
        CheckConstraint(
            "sector IS NULL OR length(trim(sector)) > 0",
            name="study_program_sector_not_blank",
        ),
        CheckConstraint("min_year >= 1", name="study_program_min_year_valid"),
        CheckConstraint("min_year <= max_year", name="study_program_years_range_valid"),
        CheckConstraint(
            "(level = 'PRIMARY_SCHOOL' AND max_year <= 5) "
            "OR (level = 'MIDDLE_SCHOOL' AND max_year <= 3) "
            "OR (level = 'HIGH_SCHOOL' AND max_year <= 5)",
            name="study_program_level_max_year_match",
        ),
        *no_surrounding_whitespace_constraints(
            "name",
            "sector",
            "description",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    level: Mapped[EducationLevelEnum] = mapped_column(
        SqlEnum(EducationLevelEnum, name="education_level_enum"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(String(255), nullable=False)

    # The sector the programme belongs to. Null where none exists, since primary
    # and middle school have no branches.
    sector: Mapped[str | None] = mapped_column(String(100), nullable=True)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    min_year: Mapped[int] = mapped_column(Integer, nullable=False)

    max_year: Mapped[int] = mapped_column(Integer, nullable=False)

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

    # The association table is reachable both as an entity (StudyProgramSubject)
    # and through this many-to-many shortcut, which is exactly the overlap
    # SQLAlchemy warns about. Declaring it says the two views of the same rows
    # are intentional; `overlaps` changes nothing at runtime.
    ministry_subjects = relationship(
        "MinistrySubject",
        secondary="study_program_subjects",
        backref=backref("study_programs", overlaps="study_program_subjects"),
        overlaps="study_program_subjects",
    )

    schools: Mapped[list[School]] = relationship(
        "School",
        secondary="school_study_programs",
        viewonly=True,
    )

    # Full name, sector included: needed wherever a programme is named outside
    # its own context, where the name alone does not identify it.
    @property
    def display_name(self) -> str:
        return f"{self.sector} | {self.name}" if self.sector else self.name
