from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    Index,
    Integer,
    String,
    text,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, backref, mapped_column, relationship

from app.core.labels import HIGH_SCHOOL_TRACK_SHORT_LABELS
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


class HighSchoolTrackEnum(StrEnum):
    BIENNIO = "BIENNIO"
    TRIENNIO = "TRIENNIO"
    QUADRIENNALE = "QUADRIENNALE"


# The single source of the mapping: the schema derives the years from it and
# the study_program_track_years_match check below repeats it in SQL.
YEARS_BY_TRACK: Final[dict[HighSchoolTrackEnum, tuple[int, int]]] = {
    HighSchoolTrackEnum.BIENNIO: (1, 2),
    HighSchoolTrackEnum.TRIENNIO: (3, 5),
    HighSchoolTrackEnum.QUADRIENNALE: (1, 4),
}


class StudyProgram(CreatedAtMixin, Base):
    __tablename__ = "study_programs"

    __table_args__ = (
        # Sector and span are both part of a programme's identity: one course
        # exists as a biennio and as a triennio under the very same name.
        # coalesce because with a NULL sector Postgres would never see two
        # rows as duplicates.
        Index(
            "uq_level_sector_program_name_years",
            "level",
            text("coalesce(sector, '')"),
            "name",
            "min_year",
            "max_year",
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
        # The HIGH_SCHOOL arm is subsumed by study_program_track_years_match
        # below; it stays because this is the only bound on the other two.
        CheckConstraint(
            "(level = 'PRIMARY_SCHOOL' AND max_year <= 5) "
            "OR (level = 'MIDDLE_SCHOOL' AND max_year <= 3) "
            "OR (level = 'HIGH_SCHOOL' AND max_year <= 5)",
            name="study_program_level_max_year_match",
        ),
        # A track is a high-school-only notion: the other two levels leave it
        # NULL. Neither side is ever NULL, so the equality is never vacuous.
        CheckConstraint(
            "(level = 'HIGH_SCHOOL') = (high_school_track IS NOT NULL)",
            name="study_program_track_only_for_high_school",
        ),
        # The years follow the track, never the keyboard: this is what makes
        # the derivation a schema fact rather than a convention.
        CheckConstraint(
            "high_school_track IS NULL "
            "OR (high_school_track = 'BIENNIO' AND min_year = 1 AND max_year = 2) "
            "OR (high_school_track = 'TRIENNIO' AND min_year = 3 AND max_year = 5) "
            "OR (high_school_track = 'QUADRIENNALE' AND min_year = 1 AND max_year = 4)",
            name="study_program_track_years_match",
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

    # Null where none exists: primary and middle school have no branches.
    sector: Mapped[str | None] = mapped_column(String(100), nullable=True)

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    min_year: Mapped[int] = mapped_column(Integer, nullable=False)

    max_year: Mapped[int] = mapped_column(Integer, nullable=False)

    # Null where none exists: only high school is split into cycles.
    high_school_track: Mapped[HighSchoolTrackEnum | None] = mapped_column(
        SqlEnum(HighSchoolTrackEnum, name="high_school_track_enum"),
        nullable=True,
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

    # The association rows are reachable both as entities and via this
    # shortcut; `overlaps` declares that intentional (no runtime effect).
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

    # The line shown above the name: sector and cycle, whichever exist.
    @property
    def scope_line(self) -> str | None:
        track = HIGH_SCHOOL_TRACK_SHORT_LABELS.get(self.high_school_track)

        parts = [part for part in (self.sector, track) if part]

        return " · ".join(parts) if parts else None

    # Full name, scope included, for contexts where the name alone is ambiguous.
    @property
    def display_name(self) -> str:
        scope = self.scope_line

        return f"{scope} | {self.name}" if scope else self.name
