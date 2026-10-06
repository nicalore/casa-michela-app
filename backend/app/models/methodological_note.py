from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core import field_lengths
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.person import Person
    from app.models.student import Student


# A psychologist's note on how a pupil learns, read by the pupil's teachers.
class MethodologicalNote(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "methodological_notes"

    __table_args__ = (
        *not_blank_constraints("text"),
        *no_surrounding_whitespace_constraints("text"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    # The person, not the psychologist row: a note outlives its author's role.
    author_tax_code: Mapped[str] = mapped_column(
        ForeignKey("people.tax_code", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    text: Mapped[str] = mapped_column(
        String(field_lengths.STUDENT_NOTE),
        nullable=False,
    )

    student: Mapped[Student] = relationship(back_populates="methodological_notes")

    author: Mapped[Person] = relationship(viewonly=True)
