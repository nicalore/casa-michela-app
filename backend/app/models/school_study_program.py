from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    ForeignKey,
    Integer,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.school import School
    from app.models.school_enrollment import SchoolEnrollment
    from app.models.study_program import StudyProgram


class SchoolStudyProgram(Base):
    __tablename__ = "school_study_programs"

    study_program_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("study_programs.id", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    school_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("schools.id", ondelete="CASCADE"),
        primary_key=True,
    )

    study_program: Mapped[StudyProgram] = relationship(
        back_populates="school_study_programs",
    )

    school: Mapped[School] = relationship(back_populates="school_study_programs")

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="school_study_program",
    )