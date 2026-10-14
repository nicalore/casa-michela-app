from collections.abc import Collection
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

# In-memory and stored readings both live here because three hooks need them.

# A discipline paired with the ministry subject it is booked under, None for
# a discipline booked on its own.
type Request = tuple[int | None, int]


# Read from __dict__: attribute access would lazy-load (no IO under async).
# None = nothing said this session (stored rows hold); empty set = truly none.
def loaded_requests(booking: Any) -> set[Request] | None:
    if booking.association_subject_id is not None:
        return {(None, booking.association_subject_id)}

    if booking.service_name is not None:
        return set()

    requested = booking.__dict__.get("subjects_requested")

    if requested is None:
        return None

    return {
        (row.ministry_subject_id, row.association_subject_id) for row in requested
    }


def loaded_disciplines(booking: Any) -> set[int] | None:
    requests = loaded_requests(booking)

    return None if requests is None else _disciplines(requests)


# Bookings with no discipline come back as empty sets, never missing keys.
def stored_requests(
    session: Session,
    booking_ids: Collection[int],
) -> dict[int, set[Request]]:
    from app.models.booking import Booking
    from app.models.subject_requested import SubjectRequested

    if not booking_ids:
        return {}

    requests: dict[int, set[Request]] = {
        booking_id: (
            {(None, association_subject_id)}
            if association_subject_id is not None
            else set()
        )
        for booking_id, association_subject_id in session.execute(
            select(Booking.id, Booking.association_subject_id).where(
                Booking.id.in_(booking_ids),
            ),
        ).all()
    }

    for booking_id, ministry_subject_id, association_subject_id in session.execute(
        select(
            SubjectRequested.booking_id,
            SubjectRequested.ministry_subject_id,
            SubjectRequested.association_subject_id,
        ).where(SubjectRequested.booking_id.in_(booking_ids)),
    ).all():
        requests.setdefault(booking_id, set()).add(
            (ministry_subject_id, association_subject_id),
        )

    return requests


def stored_disciplines(
    session: Session,
    booking_ids: Collection[int],
) -> dict[int, set[int]]:
    return {
        booking_id: _disciplines(requests)
        for booking_id, requests in stored_requests(session, booking_ids).items()
    }


def requests_of(
    session: Session,
    booking: Any,
    *,
    stored: dict[int, set[Request]] | None = None,
) -> set[Request]:
    loaded = loaded_requests(booking)

    if loaded is not None:
        return loaded

    if stored is not None and booking.id in stored:
        return stored[booking.id]

    return stored_requests(session, [booking.id]).get(booking.id, set())


def disciplines_of(session: Session, booking: Any) -> set[int]:
    return _disciplines(requests_of(session, booking))


def _disciplines(requests: set[Request]) -> set[int]:
    return {discipline for _, discipline in requests}
