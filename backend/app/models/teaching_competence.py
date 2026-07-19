from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.study_program import StudyProgram
    from app.models.teacher import Teacher


class TeachingCompetence(Base):
    __tablename__ = "teaching_competences"

    teacher_tax_code: Mapped[str] = mapped_column(
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    association_subject_id: Mapped[int] = mapped_column(
        ForeignKey("association_subjects.id", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    study_program_id: Mapped[int] = mapped_column(
        ForeignKey("study_programs.id", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    teacher: Mapped[Teacher] = relationship(
        back_populates="teaching_competences",
    )

    association_subject: Mapped[AssociationSubject] = relationship(
        back_populates="teaching_competences",
    )

    study_program: Mapped[StudyProgram] = relationship(
        back_populates="teaching_competences",
    )