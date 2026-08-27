from __future__ import annotations

from collections import Counter, defaultdict
from enum import StrEnum
from typing import TYPE_CHECKING, Final

from sqlalchemy import Enum as SqlEnum
from sqlalchemy import (
    ForeignKey,
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

# More than three is not a preference any more, it is the whole staff in order.
MAX_TEACHERS_PER_PREFERENCE_TYPE: Final[int] = 3

_TOO_MANY_PREFERRED_TEACHERS_ERROR: Final[str] = (
    "Puoi indicare al massimo tre docenti preferiti per ogni lezione"
)

_TOO_MANY_NOT_PREFERRED_TEACHERS_ERROR: Final[str] = (
    "Puoi indicare al massimo tre docenti non preferiti per ogni lezione"
)


class TeacherPreferenceTypeEnum(StrEnum):
    PREFERRED = "PREFERRED"
    NOT_PREFERRED = "NOT_PREFERRED"


# A preference, not an assignment: NOT_PREFERRED means last resort, not
# forbidden. One table so the composite PK bars a teacher from both sides.
class BookingTeacherPreference(Base):
    __tablename__ = "booking_teacher_preferences"

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

    preference_type: Mapped[TeacherPreferenceTypeEnum] = mapped_column(
        SqlEnum(TeacherPreferenceTypeEnum, name="teacher_preference_type_enum"),
        nullable=False,
    )

    booking: Mapped[Booking] = relationship(back_populates="teacher_preferences")


@event.listens_for(Session, "before_flush")
def _validate_teacher_preferences_cap(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    pending = pending_instances(session, BookingTeacherPreference)

    if not pending:
        return

    deleted_keys = {
        (instance.booking_id, instance.teacher_tax_code)
        for instance in deleted_instances(session, BookingTeacherPreference)
    }

    # Keyed per (booking, teacher): a teacher moved between sides in one
    # flush counts once, on the final side.
    staged_by_booking: dict[
        BookingFlushKey, dict[str, TeacherPreferenceTypeEnum]
    ] = defaultdict(dict)

    for preference in pending:
        key = booking_flush_key(preference)

        if key is not None:
            staged_by_booking[key][preference.teacher_tax_code] = (
                preference.preference_type
            )

    for key, staged in staged_by_booking.items():
        merged: dict[str, TeacherPreferenceTypeEnum] = {}

        # Queried explicitly: relationship collections may be unbuilt or
        # stale. Only stored bookings have rows to read.
        booking_id = stored_booking_id(key)

        if booking_id is not None:
            persisted_rows = session.execute(
                select(
                    BookingTeacherPreference.teacher_tax_code,
                    BookingTeacherPreference.preference_type,
                ).where(BookingTeacherPreference.booking_id == booking_id),
            ).all()

            merged = {
                teacher_tax_code: preference_type
                for teacher_tax_code, preference_type in persisted_rows
                if (booking_id, teacher_tax_code) not in deleted_keys
            }

        merged.update(staged)
        counts = Counter(merged.values())

        if (
            counts[TeacherPreferenceTypeEnum.PREFERRED]
            > MAX_TEACHERS_PER_PREFERENCE_TYPE
        ):
            raise ValueError(_TOO_MANY_PREFERRED_TEACHERS_ERROR)

        if (
            counts[TeacherPreferenceTypeEnum.NOT_PREFERRED]
            > MAX_TEACHERS_PER_PREFERENCE_TYPE
        ):
            raise ValueError(_TOO_MANY_NOT_PREFERRED_TEACHERS_ERROR)
