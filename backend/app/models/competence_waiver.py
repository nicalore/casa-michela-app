from __future__ import annotations

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin


# The admin let this teacher take this booking without the competence, which the
# teacher still lacks. Outlives the lesson; a booking is one day's, so is the waiver.
class CompetenceWaiver(CreatedAtMixin, Base):
    __tablename__ = "competence_waivers"

    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        primary_key=True,
    )

    teacher_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
        index=True,
    )
