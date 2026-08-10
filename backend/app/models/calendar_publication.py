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
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


# A published part of a day. The row is the fact and not a flag on something
# else: present means published, absent means not, and unpublishing is deleting
# it. A boolean would have forced a decision on what a false row means, and
# "published: no" and "never published" are the same thing.
#
# Published a band at a time — morning, afternoon, evening — because that is the
# unit an administrator actually finishes: the afternoon can be settled and sent
# out while the evening is still being arranged. Both modes go together, since a
# teacher in the building teaches the pupils in front of them and the ones on a
# screen out of the same hours.
#
# published_by survives the person: an administrator who leaves does not take
# with them the fact that the calendar went out, so the reference is nulled
# rather than cascaded.
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

    published_by: Mapped[str | None] = mapped_column(
        String(16),
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey(
            "administrators.tax_code",
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        nullable=True,
        index=True,
    )
