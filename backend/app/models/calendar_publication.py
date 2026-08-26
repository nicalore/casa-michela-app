from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class CalendarPublication(Base):
    __tablename__ = "calendar_publications"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_publication_band_valid",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)

    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    draft_snapshot: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )

    published_by: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey(
            "administrators.tax_code",
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        nullable=True,
        index=True,
    )

    # Who opened the bozza, kept for as long as it is open.
    #
    # The snapshot above is what leaving the bozza puts back, and it belongs to
    # whoever opened it: a second administrator leaving it would undo their own
    # work along with everybody else's, and would have no way of knowing. The
    # band lock cannot answer this on its own — it lasts ninety seconds and a
    # bozza lasts as long as it takes.
    draft_opened_by: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey(
            "administrators.tax_code",
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        nullable=True,
    )
