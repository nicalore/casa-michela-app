from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, ForeignKeyConstraint, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.lesson import Lesson


# Which disciplines an hour is actually spent on, out of everything the pupils
# in it asked for. Fewer than requested is the normal case rather than the
# exception: a request split in two hands part of its disciplines to one teacher
# and part to another.
#
# The two foreign keys point in opposite directions on purpose. The lesson side
# cascades, because a row here means nothing without the lesson it belongs to.
# The discipline side restricts: a discipline that appears in a past calendar
# stays in the catalogue, because deleting it would quietly rewrite what was
# taught.
class LessonDiscipline(Base):
    __tablename__ = "lesson_disciplines"

    __table_args__ = (
        # Named by hand: the convention would produce 65 characters, Postgres
        # truncates at 63, and the downgrade would then look for a name that no
        # longer exists.
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
