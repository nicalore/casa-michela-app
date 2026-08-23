from __future__ import annotations

from collections import defaultdict
from typing import TYPE_CHECKING, Any, Final

from sqlalchemy import ForeignKey, event, select
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.core.time_band import band_of
from app.core.time_step import minutes_between
from app.db.base import Base
from app.models.flush_state import (
    FlushKey,
    booking_flush_key,
    deleted_instances,
    lesson_flush_key,
    pending_instances,
    stored_id,
    stored_key,
)

if TYPE_CHECKING:
    from app.models.booking import Booking
    from app.models.lesson import Lesson

_MAX_LESSON_PARTS: Final[int] = 2

_TOO_MANY_LESSON_PARTS_ERROR: Final[str] = (
    "Una prenotazione può essere divisa in al massimo due lezioni"
)

_LESSON_PARTS_EXCEED_BOOKING_ERROR: Final[str] = (
    "Le lezioni collegate a una prenotazione non possono durare complessivamente "
    "più della prenotazione stessa"
)

_LESSON_PARTS_ACROSS_BANDS_ERROR: Final[str] = (
    "Le lezioni di una prenotazione devono stare nella stessa parte della giornata: "
    "mattino, pomeriggio e sera si pubblicano separatamente"
)


class LessonBooking(Base):
    __tablename__ = "lesson_bookings"

    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"),
        primary_key=True,
    )

    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="RESTRICT"),
        primary_key=True,
        index=True,
    )

    lesson: Mapped[Lesson] = relationship(back_populates="lesson_bookings")

    booking: Mapped[Booking] = relationship(back_populates="lesson_bookings")


def _resolve_lesson(session: Session, link: LessonBooking) -> Lesson | None:
    from app.models.lesson import Lesson

    lesson = link.__dict__.get("lesson")

    if lesson is not None:
        return lesson

    if link.lesson_id is not None:
        return session.get(Lesson, link.lesson_id)

    return None


def _span(lesson: Any) -> tuple[int, str]:
    return (
        minutes_between(lesson.start_time, lesson.end_time),
        band_of(lesson.start_time),
    )


@event.listens_for(Session, "before_flush")
def _validate_lesson_parts(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.booking import Booking
    from app.models.lesson import Lesson

    pending_links = pending_instances(session, LessonBooking)
    pending_lessons = pending_instances(session, Lesson)

    if not pending_links and not pending_lessons:
        return

    deleted_link_keys = {
        (link.lesson_id, link.booking_id)
        for link in deleted_instances(session, LessonBooking)
    }
    deleted_lesson_ids = {lesson.id for lesson in deleted_instances(session, Lesson)}

    staged: dict[FlushKey, dict[FlushKey, Any]] = defaultdict(dict)
    bookings_in_memory: dict[FlushKey, Any] = {}

    for link in pending_links:
        booking_key = booking_flush_key(link)
        lesson_key = lesson_flush_key(link)
        lesson = _resolve_lesson(session, link)

        if booking_key is None or lesson_key is None or lesson is None:
            continue

        staged[booking_key][lesson_key] = lesson

        booking = link.__dict__.get("booking")

        if booking is not None:
            bookings_in_memory[booking_key] = booking

    affected = set(staged)

    for lesson in pending_lessons:
        if lesson.id is None:
            continue

        for booking_id in session.scalars(
            select(LessonBooking.booking_id).where(
                LessonBooking.lesson_id == lesson.id,
            ),
        ).all():
            if (lesson.id, booking_id) in deleted_link_keys:
                continue

            booking_key = stored_key(booking_id)
            affected.add(booking_key)
            staged[booking_key][stored_key(lesson.id)] = lesson

    if not affected:
        return

    pending_bookings = {
        booking.id: booking
        for booking in pending_instances(session, Booking)
        if booking.id is not None
    }

    for booking_key in affected:
        booking_id = stored_id(booking_key)
        booking = bookings_in_memory.get(booking_key)

        if booking is None and booking_id is not None:
            booking = pending_bookings.get(booking_id)

        if booking is not None:
            duration = booking.duration
        elif booking_id is not None:
            duration = session.scalar(
                select(Booking.duration).where(Booking.id == booking_id),
            )
        else:
            continue

        if duration is None:
            continue

        parts: dict[FlushKey, tuple[int, str]] = {}

        if booking_id is not None:
            for lesson_id, start_time, end_time in session.execute(
                select(Lesson.id, Lesson.start_time, Lesson.end_time)
                .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
                .where(LessonBooking.booking_id == booking_id),
            ).all():
                if (
                    lesson_id in deleted_lesson_ids
                    or (lesson_id, booking_id) in deleted_link_keys
                ):
                    continue

                parts[stored_key(lesson_id)] = (
                    minutes_between(start_time, end_time),
                    band_of(start_time),
                )

        for lesson_key, lesson in staged[booking_key].items():
            parts[lesson_key] = _span(lesson)

        if len(parts) > _MAX_LESSON_PARTS:
            raise ValueError(_TOO_MANY_LESSON_PARTS_ERROR)

        if sum(minutes for minutes, _ in parts.values()) > duration:
            raise ValueError(_LESSON_PARTS_EXCEED_BOOKING_ERROR)

        if len({band for _, band in parts.values()}) > 1:
            raise ValueError(_LESSON_PARTS_ACROSS_BANDS_ERROR)
