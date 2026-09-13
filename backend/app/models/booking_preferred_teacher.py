from __future__ import annotations

from typing import TYPE_CHECKING, Final

from sqlalchemy import ForeignKey, event, select
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

# More than three is not a preference any more, it is the whole staff in order.
MAX_PREFERRED_TEACHERS_PER_BOOKING: Final[int] = 3

_TOO_MANY_PREFERRED_TEACHERS_ERROR: Final[str] = (
    "Puoi indicare al massimo tre docenti preferiti per ogni lezione"
)


# A preference, not an assignment. The teachers a pupil would rather not
# have are kept on the pupil (StudentNotPreferredTeacher), not per booking.
class BookingPreferredTeacher(Base):
    __tablename__ = "booking_preferred_teachers"

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

    booking: Mapped[Booking] = relationship(back_populates="preferred_teachers")


@event.listens_for(Session, "before_flush")
def _validate_preferred_teachers_cap(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    pending = pending_instances(session, BookingPreferredTeacher)

    if not pending:
        return

    deleted_keys = {
        (instance.booking_id, instance.teacher_tax_code)
        for instance in deleted_instances(session, BookingPreferredTeacher)
    }

    staged_by_booking: dict[BookingFlushKey, set[str]] = {}

    for preference in pending:
        key = booking_flush_key(preference)

        if key is not None:
            staged_by_booking.setdefault(key, set()).add(preference.teacher_tax_code)

    for key, staged in staged_by_booking.items():
        merged = set(staged)

        # Queried explicitly: relationship collections may be unbuilt or
        # stale. Only stored bookings have rows to read.
        booking_id = stored_booking_id(key)

        if booking_id is not None:
            persisted = session.scalars(
                select(BookingPreferredTeacher.teacher_tax_code).where(
                    BookingPreferredTeacher.booking_id == booking_id,
                ),
            ).all()

            merged.update(
                teacher_tax_code
                for teacher_tax_code in persisted
                if (booking_id, teacher_tax_code) not in deleted_keys
            )

        if len(merged) > MAX_PREFERRED_TEACHERS_PER_BOOKING:
            raise ValueError(_TOO_MANY_PREFERRED_TEACHERS_ERROR)
