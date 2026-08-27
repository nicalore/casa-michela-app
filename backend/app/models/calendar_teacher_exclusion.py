from __future__ import annotations

from datetime import date

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin


# Marks a teacher as excluded from one (day, band) calendar; undone by deleting
# the row. CASCADE on the teacher: this is a build-time note, not a record.
class CalendarTeacherExclusion(CreatedAtMixin, Base):
    __tablename__ = "calendar_teacher_exclusions"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_teacher_exclusion_band_valid",
        ),
        Index("ix_calendar_teacher_exclusion_band", "date", "band"),
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
