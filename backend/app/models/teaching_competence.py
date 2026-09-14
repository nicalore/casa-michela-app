from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.booking_window import today_in_rome
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.study_program import StudyProgram
    from app.models.teacher import Teacher


# Dated like a pupil's opinions: withdrawing a competence closes the row, so
# the statistics can still tell which lessons the teacher could have taught
# back then. The parents' collections list open rows only.
class TeachingCompetence(Base):
    __tablename__ = "teaching_competences"

    __table_args__ = (
        # Empty intervals are deleted, never stored.
        CheckConstraint(
            "valid_to IS NULL OR valid_to > valid_from",
            name="validity_ends_after_start",
        ),
        Index(
            "ux_teaching_competence_open",
            "teacher_tax_code",
            "association_subject_id",
            "study_program_id",
            unique=True,
            postgresql_where=text("valid_to IS NULL"),
        ),
    )

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

    valid_from: Mapped[date] = mapped_column(
        Date,
        primary_key=True,
        default=today_in_rome,
    )

    # Exclusive; NULL while the competence stands.
    valid_to: Mapped[date | None] = mapped_column(Date, nullable=True)

    teacher: Mapped[Teacher] = relationship()

    association_subject: Mapped[AssociationSubject] = relationship()

    study_program: Mapped[StudyProgram] = relationship()
