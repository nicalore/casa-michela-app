from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.person import Person


# A pupil's standing opinion; withdrawing closes the row, so past rankings keep it.
class StudentNotPreferredTeacher(Base):
    __tablename__ = "student_not_preferred_teachers"

    __table_args__ = (
        # Empty intervals are deleted, never stored.
        CheckConstraint(
            "valid_to IS NULL OR valid_to > valid_from",
            name="validity_ends_after_start",
        ),
        Index(
            "ux_student_not_preferred_teacher_open",
            "student_tax_code",
            "teacher_tax_code",
            unique=True,
            postgresql_where=text("valid_to IS NULL"),
        ),
    )

    student_tax_code: Mapped[str] = mapped_column(
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    teacher_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
        index=True,
    )

    valid_from: Mapped[date] = mapped_column(Date, primary_key=True)

    # Exclusive; NULL while the opinion stands.
    valid_to: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Names live on Person, one join away from the teacher's tax code.
    person: Mapped[Person] = relationship(
        primaryjoin="StudentNotPreferredTeacher.teacher_tax_code == Person.tax_code",
        foreign_keys="StudentNotPreferredTeacher.teacher_tax_code",
        viewonly=True,
    )
