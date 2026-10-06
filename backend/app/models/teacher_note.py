from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Date, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core import field_lengths
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
)
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.person import Person
    from app.models.student import Student


# A teacher's note after a lesson, for the administrators only; never changed.
class TeacherNote(CreatedAtMixin, Base):
    __tablename__ = "teacher_notes"

    __table_args__ = (
        *not_blank_constraints("text", "subject"),
        *no_surrounding_whitespace_constraints("text", "subject"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    # The person, not the teacher row: a note outlives its author's role.
    author_tax_code: Mapped[str] = mapped_column(
        ForeignKey("people.tax_code", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    # Kept when the lesson goes: day and subject are copied below for that.
    lesson_id: Mapped[int | None] = mapped_column(
        ForeignKey("lessons.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    lesson_date: Mapped[date] = mapped_column(Date, nullable=False)

    # The name the teacher read on the lesson: discipline, ministry subject or service.
    subject: Mapped[str] = mapped_column(String(field_lengths.NAME), nullable=False)

    text: Mapped[str] = mapped_column(
        String(field_lengths.STUDENT_NOTE),
        nullable=False,
    )

    student: Mapped[Student] = relationship(back_populates="teacher_notes")

    author: Mapped[Person] = relationship(viewonly=True)
