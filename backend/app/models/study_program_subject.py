from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    ForeignKey,
    Integer,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.ministry_subject import MinistrySubject
    from app.models.study_program import StudyProgram


class StudyProgramSubject(Base):
    __tablename__ = "study_program_subjects"

    study_program_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("study_programs.id", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    ministry_subject_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("ministry_subjects.id", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    # These rows are also reached through the StudyProgram <-> MinistrySubject
    # many-to-many shortcut: `overlaps` declares that as intentional and changes
    # nothing at runtime.
    study_program: Mapped[StudyProgram] = relationship(
        back_populates="study_program_subjects",
        overlaps="ministry_subjects,study_programs",
    )

    ministry_subject: Mapped[MinistrySubject] = relationship(
        back_populates="study_program_subjects",
        overlaps="ministry_subjects,study_programs",
    )