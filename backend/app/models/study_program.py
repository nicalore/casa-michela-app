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
    from app.models.teaching_offering import TeachingOffering


class StudyProgram(Base):
    __tablename__ = "study_programs"

    __table_args__ = (
        UniqueConstraint(
            "name",
            name="uq_study_program_name",
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

    teaching_offerings: Mapped[list[TeachingOffering]] = relationship(
        back_populates="study_program",
    )