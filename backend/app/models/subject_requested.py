from __future__ import annotations

from collections import defaultdict
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    event,
    select,
)
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.db.base import Base
from app.models.flush_state import (
    BookingFlushKey,
    booking_flush_key,
    deleted_instances,
    pending_instances,
    stored_booking_id,
)

if TYPE_CHECKING:
    from app.models.booking import Booking
    from app.models.ministry_association_subject import MinistryAssociationSubject

_MIXED_MINISTRY_SUBJECTS_PER_BOOKING_ERROR: Final[str] = (
    "Tutte le materie richieste per una stessa prenotazione devono "
    "appartenere alla stessa materia ministeriale"
)


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


@event.listens_for(Session, "before_flush")
def _validate_subject_requested_ministry_subject_consistency(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    pending_requests = pending_instances(session, SubjectRequested)

    if not pending_requests:
        return

    deleted_keys = {
        (
            instance.booking_id,
            instance.ministry_subject_id,
            instance.association_subject_id,
        )
        for instance in deleted_instances(session, SubjectRequested)
    }

    # Keyed via booking_flush_key: unflushed bookings have no booking_id yet
    # and grouping on it would skip them.
    staged_by_booking: dict[BookingFlushKey, set[int]] = defaultdict(set)

    for request in pending_requests:
        key = booking_flush_key(request)

        if key is not None:
            staged_by_booking[key].add(request.ministry_subject_id)

    for key, staged_ministry_subject_ids in staged_by_booking.items():
        ministry_subject_ids = set(staged_ministry_subject_ids)

        # Only a stored booking has rows to reconcile against.
        booking_id = stored_booking_id(key)

        # Queried explicitly: relationship collections may be unbuilt or stale.
        if booking_id is not None:
            persisted_rows = session.execute(
                select(
                    SubjectRequested.ministry_subject_id,
                    SubjectRequested.association_subject_id,
                ).where(SubjectRequested.booking_id == booking_id),
            ).all()

            ministry_subject_ids |= {
                ministry_subject_id
                for ministry_subject_id, association_subject_id in persisted_rows
                if (booking_id, ministry_subject_id, association_subject_id)
                not in deleted_keys
            }

        if len(ministry_subject_ids) > 1:
            raise ValueError(_MIXED_MINISTRY_SUBJECTS_PER_BOOKING_ERROR)
