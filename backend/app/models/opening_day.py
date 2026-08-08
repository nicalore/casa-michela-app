from __future__ import annotations

from datetime import date, time

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    Index,
    Integer,
    String,
    Text,
    Time,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin


class OpeningDay(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "opening_days"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_opening_day_id"),
        CheckConstraint("mode IN ('presence', 'online')", name="opening_day_mode_valid"),
        CheckConstraint(
            "(start_time IS NULL AND end_time IS NULL) OR (end_time > start_time)",
            name="opening_day_closed_or_end_after_start",
        ),
        Index(
            "ux_opening_day_closure",
            "date",
            "mode",
            unique=True,
            postgresql_where=text("start_time IS NULL"),
        ),
        Index(
            "ux_opening_day_slot",
            "date",
            "mode",
            "start_time",
            unique=True,
            postgresql_where=text("start_time IS NOT NULL"),
        ),
        *not_blank_when_present_constraints("note"),
        *no_surrounding_whitespace_constraints("note"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    # NULL means closed on that day.
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    end_time: Mapped[time | None] = mapped_column(Time, nullable=True)

    is_override: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )

    note: Mapped[str | None] = mapped_column(Text, nullable=True)
