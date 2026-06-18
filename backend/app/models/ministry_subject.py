from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Integer,
    String,
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
    from app.models.ministry_association_subject import MinistryAssociationSubject
    from app.models.study_program_subject import StudyProgramSubject


class MinistrySubject(Base):
    __tablename__ = "ministry_subjects"

    __table_args__ = (
        UniqueConstraint(
            "name",
            name="uq_ministry_subject_name",
        ),
        CheckConstraint(
            "id > 0",
            name="positive_ministry_subject_id",
        ),
        CheckConstraint(
            "length(trim(name)) > 0",
            name="ministry_subject_name_not_blank",
        ),
        CheckConstraint(
            """
            description IS NULL
            OR length(trim(description)) > 0
            """,
            name="ministry_subject_description_not_blank",
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

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        String(1000),
        nullable=True,
    )

    study_program_subjects: Mapped[list[StudyProgramSubject]] = relationship(
        back_populates="ministry_subject",
        cascade="all, delete-orphan",
    )

    ministry_association_subjects: Mapped[list[MinistryAssociationSubject]] = relationship(
        back_populates="ministry_subject",
        cascade="all, delete-orphan",
    )