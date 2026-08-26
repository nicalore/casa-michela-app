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

# How long a lock outlives the last sign of life from whoever holds it. The
# client beats every 30 seconds, so three beats fit in the window and two lost
# ones are survivable.
#
# Nothing sweeps the expired rows: the age is read together with the row, so a
# lock whose holder closed the browser is already free to whoever reads next.
# That is the whole guarantee, and there is no job in it that could fail to run.
LOCK_TTL_SECONDS: Final[int] = 90


# Who is building a part of a day right now.
#
# Its own table and not a column on calendar_publications, because there a row
# existing *is* the band being published — is_published asks nothing else — and
# a band needs a holder exactly while it has never been published at all.
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

    # When the band was taken, which is what the banner says out loud ("sta
    # modificando dalle 14:32"). A beat moves heartbeat_at and leaves this
    # alone, so it keeps meaning the start of the sitting rather than its last
    # sign of life.
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
