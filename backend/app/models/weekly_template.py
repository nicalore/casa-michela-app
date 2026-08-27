from __future__ import annotations

from datetime import date, time

from sqlalchemy import (
    CheckConstraint,
    Date,
    Integer,
    SmallInteger,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import UpdatedAtMixin


class WeeklyTemplate(UpdatedAtMixin, Base):
    __tablename__ = "weekly_templates"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_weekly_template_id"),
        CheckConstraint("weekday BETWEEN 1 AND 7", name="weekly_template_weekday_range"),
        CheckConstraint("mode IN ('presence', 'online')", name="weekly_template_mode_valid"),
        CheckConstraint("end_time > start_time", name="weekly_template_end_after_start"),
        UniqueConstraint(
            "weekday",
            "mode",
            "start_time",
            name="uq_weekly_templates_weekday_mode_start_time",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # 1=Monday .. 7=Sunday, per ISO 8601.
    weekday: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    # Generation applies this rule only from this date on.
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)
