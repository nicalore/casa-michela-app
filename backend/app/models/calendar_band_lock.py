from __future__ import annotations

from datetime import date, datetime
from typing import Final

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

# The client beats every 30s: three beats fit the window, two lost survive.
# Expired rows are never swept — age is read with the row, so a dead holder's
# lock is already free to the next reader.
LOCK_TTL_SECONDS: Final[int] = 90


# Its own table: a calendar_publications row existing means published, while
# a band needs a holder precisely while it is unpublished.
class CalendarBandLock(Base):
    __tablename__ = "calendar_band_locks"

    __table_args__ = (
        CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_band_lock_band_valid",
        ),
    )

    date: Mapped[date] = mapped_column(Date, primary_key=True)

    band: Mapped[str] = mapped_column(String(20), primary_key=True)

    holder_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey(
            "administrators.tax_code",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    # Start of the sitting (shown in the banner); beats move only heartbeat_at.
    acquired_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    heartbeat_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
