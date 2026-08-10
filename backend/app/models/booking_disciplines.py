from collections.abc import Collection
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

# Which disciplines an hour is spent on. There are three shapes of request and
# each answers the question differently: a discipline asked on its own is that
# one discipline, a service is no discipline at all, and a ministry subject is
# whichever disciplines were requested under it.
#
# Both readings live here, in memory and from the database, because three
# different hooks need them and had begun to keep three copies.


# What the booking says as it stands in this session, or None where nothing in
# it answers the question and the stored rows still hold.
#
# Read out of __dict__ rather than off the attribute: an hour whose subjects
# nobody touched has an unloaded collection there, and asking for it under async
# is a lazy load in a place that cannot do IO. None means exactly that — nothing
# was said — and an empty set means a booking that really carries no requested
# subject, which is every shape but the ministry one.
#
# The children are not read back from the database for a booking being rewritten
# either: the rows a replacement discards are not among session.deleted until
# the flush proper, so the collection just assigned is the only honest answer.
def loaded_disciplines(booking: Any) -> set[int] | None:
    if booking.association_subject_id is not None:
        return {booking.association_subject_id}

    if booking.service_name is not None:
        return set()

    requested = booking.__dict__.get("subjects_requested")

    if requested is None:
        return None

    return {row.association_subject_id for row in requested}


# The same answer for rows already in the database, in two queries rather than
# one per booking. Bookings with no discipline at all — services — come back
# with an empty set rather than missing from the mapping, so callers never have
# to tell "no disciplines" apart from "not asked about".
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

    # Only a ministry request has rows here, and the shape above already left it
    # an empty set to fill.
    for booking_id, association_subject_id in session.execute(
        select(
            SubjectRequested.booking_id,
            SubjectRequested.association_subject_id,
        ).where(SubjectRequested.booking_id.in_(booking_ids)),
    ).all():
        disciplines.setdefault(booking_id, set()).add(association_subject_id)

    return disciplines


# What this booking covers, whatever state it is in: what it says now when it
# says anything, and what is stored otherwise.
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
