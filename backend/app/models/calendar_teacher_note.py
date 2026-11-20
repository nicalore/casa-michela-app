from __future__ import annotations

from datetime import date

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin


# An administrator's note to one teacher about one (day, band) calendar, read
# by that teacher alone once the band is published.
class CalendarTeacherNote(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "calendar_teacher_notes"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_teacher_note_band_valid",
        ),
        *not_blank_constraints("text"),
        *no_surrounding_whitespace_constraints("text"),
        Index("ix_calendar_teacher_note_band", "date", "band"),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)

    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    teacher_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey(
            "teachers.tax_code",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        primary_key=True,
    )

    text: Mapped[str] = mapped_column(String(1000), nullable=False)

    # Whoever last wrote the text; the teacher reads the name beside it.
    author_tax_code: Mapped[str | None] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        nullable=True,
        index=True,
    )
