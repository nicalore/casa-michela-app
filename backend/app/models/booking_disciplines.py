from collections.abc import Collection
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

# In-memory and stored readings both live here because three hooks need them.


# Read from __dict__: attribute access would lazy-load (no IO under async).
# None = nothing said this session (stored rows hold); empty set = truly none.
def loaded_disciplines(booking: Any) -> set[int] | None:
    if booking.association_subject_id is not None:
        return {booking.association_subject_id}

    if booking.service_name is not None:
        return set()

    requested = booking.__dict__.get("subjects_requested")

    if requested is None:
        return None

    return {row.association_subject_id for row in requested}


# Bookings with no discipline come back as empty sets, never missing keys.
def stored_disciplines(
    session: Session,
    booking_ids: Collection[int],
) -> dict[int, set[int]]:
    from app.models.booking import Booking
    from app.models.subject_requested import SubjectRequested

    if not booking_ids:
        return {}

    disciplines: dict[int, set[int]] = {
        booking_id: (
            {association_subject_id} if association_subject_id is not None else set()
        )
        for booking_id, association_subject_id in session.execute(
            select(Booking.id, Booking.association_subject_id).where(
                Booking.id.in_(booking_ids),
            ),
        ).all()
    }

    for booking_id, association_subject_id in session.execute(
        select(
            SubjectRequested.booking_id,
            SubjectRequested.association_subject_id,
        ).where(SubjectRequested.booking_id.in_(booking_ids)),
    ).all():
        disciplines.setdefault(booking_id, set()).add(association_subject_id)

    return disciplines


def disciplines_of(
    session: Session,
    booking: Any,
    *,
    stored: dict[int, set[int]] | None = None,
) -> set[int]:
    loaded = loaded_disciplines(booking)

    if loaded is not None:
        return loaded

    if stored is not None and booking.id in stored:
        return stored[booking.id]

    return stored_disciplines(session, [booking.id]).get(booking.id, set())
