from typing import Any, Final

from sqlalchemy.orm import Session

_STORED: Final[str] = "stored"
_PENDING: Final[str] = "pending"

# ("stored", parent_id) for a parent that is already in the database,
# ("pending", id(parent)) for one being written in this very flush.
FlushKey = tuple[str, object]

# Legacy alias from when bookings were the only parent needing this.
BookingFlushKey = FlushKey


def new_instances[T](session: Session, model: type[T]) -> list[T]:
    return [instance for instance in session.new if isinstance(instance, model)]


def pending_instances[T](session: Session, model: type[T]) -> list[T]:
    return [
        instance
        for instance in session.new.union(session.dirty)
        if isinstance(instance, model)
    ]


def deleted_instances[T](session: Session, model: type[T]) -> list[T]:
    return [instance for instance in session.deleted if isinstance(instance, model)]


# Falls back on parent object identity while the FK is unset; tagged because
# id() is an int too and a bare address must never reach a WHERE clause.
# Parent is read from __dict__, so no lazy load (MissingGreenlet under async).
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


# None for a brand-new parent: no stored rows to reconcile against.
def stored_id(key: FlushKey) -> Any | None:
    kind, value = key

    return value if kind == _STORED else None


pending_booking_key = pending_key
stored_booking_key = stored_key
stored_booking_id = stored_id
