from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, ForeignKeyConstraint, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.booking import Booking
    from app.models.ministry_association_subject import MinistryAssociationSubject


class SubjectRequested(Base):
    __tablename__ = "subjects_requested"

    __table_args__ = (
        ForeignKeyConstraint(
            ["ministry_subject_id", "association_subject_id"],
            [
                "ministry_association_subjects.ministry_subject_id",
                "ministry_association_subjects.association_subject_id",
            ],
            ondelete="CASCADE",
            onupdate="CASCADE",
            name="subjects_requested_mas_fkey",
        ),
        # One discipline per booking. Deferred: a flush inserts the new row
        # before it deletes the old one.
        UniqueConstraint("booking_id", deferrable=True, initially="DEFERRED"),
    )

    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        primary_key=True,
    )

    ministry_subject_id: Mapped[int] = mapped_column(Integer, primary_key=True)

    association_subject_id: Mapped[int] = mapped_column(Integer, primary_key=True)

    booking: Mapped[Booking] = relationship(back_populates="subjects_requested")

    ministry_association_subject: Mapped[MinistryAssociationSubject] = relationship(
        back_populates="subjects_requested",
    )
