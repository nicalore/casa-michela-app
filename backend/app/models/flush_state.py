from typing import Any, Final

from sqlalchemy.orm import Session

_STORED: Final[str] = "stored"
_PENDING: Final[str] = "pending"

# ("stored", booking_id) for a booking that is already in the database,
# ("pending", id(booking)) for one being written in this very flush.
BookingFlushKey = tuple[str, object]


# Rows inserted by the flush about to happen.
def new_instances[T](session: Session, model: type[T]) -> list[T]:
    return [instance for instance in session.new if isinstance(instance, model)]


# Rows either inserted or edited by the flush about to happen.
def pending_instances[T](session: Session, model: type[T]) -> list[T]:
    return [
        instance
        for instance in session.new.union(session.dirty)
        if isinstance(instance, model)
    ]


def deleted_instances[T](session: Session, model: type[T]) -> list[T]:
    return [instance for instance in session.deleted if isinstance(instance, model)]


# Which Booking a child row belongs to, even before it has been flushed. A child
# built through the relationship has no booking_id yet, so it falls back on the
# identity of the Booking object itself — the only thing its siblings share
# during this flush. The key is tagged because id() returns an int too, and
# without the tag a memory address could end up in a WHERE clause.
#
# Safe without IO: when booking_id is None the object came from the
# relationship, so `booking` is already in the instance __dict__ and reading it
# triggers no lazy load (which under async would raise MissingGreenlet).
def booking_flush_key(child: Any) -> BookingFlushKey | None:
    if child.booking_id is not None:
        return (_STORED, child.booking_id)

    if child.booking is not None:
        return (_PENDING, id(child.booking))

    return None


def pending_booking_key(booking: Any) -> BookingFlushKey:
    return (_PENDING, id(booking))


def stored_booking_key(booking_id: int) -> BookingFlushKey:
    return (_STORED, booking_id)


# The database id behind a flush key, or None for a brand-new booking: callers
# use it to decide whether there are stored rows to reconcile against at all.
def stored_booking_id(key: BookingFlushKey) -> int | None:
    kind, value = key

    return value if kind == _STORED else None
