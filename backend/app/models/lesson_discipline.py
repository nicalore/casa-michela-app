from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, ForeignKeyConstraint, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.lesson import Lesson


# Fewer disciplines than requested is normal (split requests spread them).
# Lesson FK cascades; discipline FK RESTRICTs so past calendars keep their record.
class LessonDiscipline(Base):
    __tablename__ = "lesson_disciplines"

    __table_args__ = (
        # Named by hand: the conventional name exceeds Postgres's 63-char
        # limit and the truncated name would break the downgrade.
        ForeignKeyConstraint(
            ["association_subject_id"],
            ["association_subjects.id"],
            ondelete="RESTRICT",
            onupdate="CASCADE",
            name="lesson_disciplines_subject_fkey",
        ),
    )

    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"),
        primary_key=True,
    )

    association_subject_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
    )

    lesson: Mapped[Lesson] = relationship(back_populates="lesson_disciplines")

    association_subject: Mapped[AssociationSubject] = relationship()
