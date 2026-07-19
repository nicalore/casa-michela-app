from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.ministry_association_subject import MinistryAssociationSubject
    from app.models.teaching_competence import TeachingCompetence


class SubjectAreaEnum(StrEnum):
    HUMANITIES = "HUMANITIES"
    LINGUISTICS = "LINGUISTICS"
    SCIENCES = "SCIENCES"


class AssociationSubject(CreatedAtMixin, Base):
    __tablename__ = "association_subjects"

    __table_args__ = (
        UniqueConstraint("name", name="uq_association_subject_name"),
        CheckConstraint("id > 0", name="positive_association_subject_id"),
        CheckConstraint(
            "length(trim(name)) > 0",
            name="association_subject_name_not_blank",
        ),
        CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name="association_subject_description_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "name",
            "description",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)

    area: Mapped[SubjectAreaEnum] = mapped_column(
        SqlEnum(SubjectAreaEnum, name="subject_area_enum"),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    ministry_association_subjects: Mapped[list[MinistryAssociationSubject]] = relationship(
        back_populates="association_subject",
        cascade="all, delete-orphan",
    )

    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        back_populates="association_subject",
        cascade="all, delete-orphan",
    )