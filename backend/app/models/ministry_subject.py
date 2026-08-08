from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, backref, mapped_column, relationship

from app.db.base import Base
from app.models.association_subject import SubjectAreaEnum
from app.models.constraints import no_surrounding_whitespace_constraints
from app.models.mixins import CreatedAtMixin
from app.models.study_program import EducationLevelEnum

if TYPE_CHECKING:
    from app.models.ministry_association_subject import MinistryAssociationSubject
    from app.models.study_program_subject import StudyProgramSubject


class MinistrySubject(CreatedAtMixin, Base):
    __tablename__ = "ministry_subjects"

    __table_args__ = (
        UniqueConstraint("level", "name", name="uq_level_ministry_subject_name"),
        CheckConstraint("id > 0", name="positive_ministry_subject_id"),
        CheckConstraint(
            "length(trim(name)) > 0",
            name="ministry_subject_name_not_blank",
        ),
        CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name="ministry_subject_description_not_blank",
        ),
        CheckConstraint(
            "cardinality(area) BETWEEN 1 AND 3",
            name="ministry_subject_area_count_range",
        ),
        CheckConstraint(
            "(area[1] IS DISTINCT FROM area[2] OR area[2] IS NULL) "
            "AND (area[1] IS DISTINCT FROM area[3] OR area[3] IS NULL) "
            "AND (area[2] IS DISTINCT FROM area[3] OR area[3] IS NULL)",
            name="ministry_subject_area_no_duplicates",
        ),
        *no_surrounding_whitespace_constraints(
            "name",
            "description",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    level: Mapped[EducationLevelEnum] = mapped_column(
        SqlEnum(EducationLevelEnum, name="education_level_enum"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(String(255), nullable=False)

    area: Mapped[list[SubjectAreaEnum]] = mapped_column(
        ARRAY(SqlEnum(SubjectAreaEnum, name="subject_area_enum")),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # Both association tables are reachable as entities and through a
    # many-to-many shortcut: `overlaps` declares the two views of the same rows
    # as intentional and changes nothing at runtime.
    study_program_subjects: Mapped[list[StudyProgramSubject]] = relationship(
        back_populates="ministry_subject",
        cascade="all, delete-orphan",
        overlaps="ministry_subjects,study_programs",
    )

    ministry_association_subjects: Mapped[list[MinistryAssociationSubject]] = (
        relationship(
            back_populates="ministry_subject",
            cascade="all, delete-orphan",
            overlaps="association_subjects,ministry_subjects",
        )
    )

    association_subjects = relationship(
        "AssociationSubject",
        secondary="ministry_association_subjects",
        backref=backref(
            "ministry_subjects",
            overlaps=(
                "association_subject,ministry_association_subjects,ministry_subject"
            ),
        ),
        overlaps=(
            "association_subject,ministry_association_subjects,ministry_subject"
        ),
    )