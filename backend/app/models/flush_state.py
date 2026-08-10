from typing import Any, Final

from sqlalchemy.orm import Session

_STORED: Final[str] = "stored"
_PENDING: Final[str] = "pending"

# ("stored", parent_id) for a parent that is already in the database,
# ("pending", id(parent)) for one being written in this very flush.
FlushKey = tuple[str, object]

# The name this pair went by when bookings were the only parent that needed it.
BookingFlushKey = FlushKey


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


# Which parent a child row belongs to, even before it has been flushed. A child
# built through the relationship has no foreign key yet, so it falls back on the
# identity of the parent object itself — the only thing its siblings share
# during this flush. The key is tagged because id() returns an int too, and
# without the tag a memory address could end up in a WHERE clause.
#
# Safe without IO: when the foreign key is None the object came from the
# relationship, so the parent is already in the instance __dict__ and reading it
# triggers no lazy load (which under async would raise MissingGreenlet).
def parent_flush_key(
    child: Any,
    *,
    id_attr: str,
    relationship_attr: str,
) -> FlushKey | None:
    parent_id = getattr(child, id_attr)

    if parent_id is not None:
        return (_STORED, parent_id)

    parent = getattr(child, relationship_attr)

    if parent is not None:
        return (_PENDING, id(parent))

    return None


def booking_flush_key(child: Any) -> FlushKey | None:
    return parent_flush_key(child, id_attr="booking_id", relationship_attr="booking")


def lesson_flush_key(child: Any) -> FlushKey | None:
    return parent_flush_key(child, id_attr="lesson_id", relationship_attr="lesson")


def pending_key(parent: Any) -> FlushKey:
    return (_PENDING, id(parent))


def stored_key(entity_id: object) -> FlushKey:
    return (_STORED, entity_id)


# The database id behind a flush key, or None for a brand-new parent: callers
# use it to decide whether there are stored rows to reconcile against at all.
def stored_id(key: FlushKey) -> Any | None:
    kind, value = key

    return value if kind == _STORED else None


pending_booking_key = pending_key
stored_booking_key = stored_key
stored_booking_id = stored_id
