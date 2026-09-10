from __future__ import annotations

from datetime import time
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core import field_lengths
from app.core.time_band import EVENING_START
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
)

if TYPE_CHECKING:
    from app.models.student import Student

# The paper form holds two lines of days, and so does the register.
MAXIMUM_SCHEDULES: Final[int] = 2

WEEKDAYS: Final[tuple[int, ...]] = (1, 2, 3, 4, 5, 6, 7)

_WEEKDAY_ARRAY: Final[str] = (
    "ARRAY[" + ", ".join(str(weekday) for weekday in WEEKDAYS) + "]::smallint[]"
)

_CLOSING_TIME: Final[str] = EVENING_START.strftime("%H:%M")


class EarlyExitSchedule(Base):
    __tablename__ = "early_exit_schedules"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_early_exit_schedule_id"),
        # Ordinal doubles as the cap: there is no third line to number.
        CheckConstraint(
            f"ordinal BETWEEN 1 AND {MAXIMUM_SCHEDULES}",
            name="early_exit_schedule_ordinal_range",
        ),
        CheckConstraint(
            "cardinality(weekdays) > 0",
            name="early_exit_schedule_has_a_weekday",
        ),
        CheckConstraint(
            f"weekdays <@ {_WEEKDAY_ARRAY}",
            name="early_exit_schedule_weekday_range",
        ),
        # Leaving at or after the end of the activities is not an early exit.
        CheckConstraint(
            f"exit_time < TIME '{_CLOSING_TIME}'",
            name="early_exit_schedule_before_closing",
        ),
        UniqueConstraint(
            "student_tax_code",
            "ordinal",
            name="uq_early_exit_schedules_student_ordinal",
        ),
        *not_blank_constraints("reason"),
        *no_surrounding_whitespace_constraints("reason"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    student_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    # Which line of the form this is, 1 or 2.
    ordinal: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    # 1=Monday .. 7=Sunday, per ISO 8601.
    weekdays: Mapped[list[int]] = mapped_column(
        ARRAY(SmallInteger),
        nullable=False,
    )

    exit_time: Mapped[time] = mapped_column(Time, nullable=False)

    reason: Mapped[str] = mapped_column(
        String(field_lengths.EARLY_EXIT_REASON),
        nullable=False,
    )

    student: Mapped[Student] = relationship(back_populates="early_exit_schedules")
