from __future__ import annotations

from datetime import date, time
from typing import TYPE_CHECKING, Any, Final

from sqlalchemy import (
    CheckConstraint,
    Computed,
    Date,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Time,
    event,
    select,
)
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.db.base import Base
from app.models.flush_state import deleted_instances, pending_instances
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.availability import Availability
    from app.models.lesson_booking import LessonBooking
    from app.models.lesson_discipline import LessonDiscipline

_LESSON_WITHOUT_BOOKING_ERROR: Final[str] = (
    "Una lezione deve avere almeno una prenotazione"
)

_DISCIPLINE_NOT_REQUESTED_ERROR: Final[str] = (
    "Ogni disciplina della lezione deve essere collegata ad almeno una delle "
    "prenotazioni"
)

_BOOKING_NOT_ON_LESSON_SUBJECT_ERROR: Final[str] = (
    "Ogni prenotazione deve avere almeno una disciplina in comune con la lezione"
)

_LESSON_WITHOUT_DISCIPLINE_ERROR: Final[str] = (
    "Solo i servizi non hanno discipline"
)

_MODE_MISMATCH_ERROR: Final[str] = (
    "Una lezione si deve svolgere interamente nella stessa modalità"
)

_DATE_MISMATCH_ERROR: Final[str] = (
    "Le prenotazioni di una lezione devono essere nello stesso giorno della lezione"
)

# Must stay in sync with the bounds in app/core/time_band.py.
_BAND_EXPRESSION: Final[str] = (
    "CASE WHEN start_time < TIME '13:00' THEN 'MORNING' "
    "WHEN start_time < TIME '19:00' THEN 'AFTERNOON' "
    "ELSE 'EVENING' END"
)

_LinkKey = tuple[Any, Any]


# date and teacher_mode are denormalized but kept honest by the composite FK;
# RESTRICT (and no onupdate) makes moving or deleting a booked availability fail.
class Lesson(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "lessons"

    __table_args__ = (
        ForeignKeyConstraint(
            ["availability_id", "date", "teacher_mode"],
            [
                "availabilities.id",
                "availabilities.date",
                "availabilities.mode",
            ],
            ondelete="RESTRICT",
            name="lessons_availability_fkey",
        ),
        CheckConstraint("id > 0", name="positive_lesson_id"),
        CheckConstraint("end_time > start_time", name="lesson_end_after_start"),
        # Subsumes the check above, kept for its distinct error name.
        CheckConstraint(
            "end_time - start_time >= INTERVAL '30 minutes'",
            name="lesson_minimum_duration",
        ),
        CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name="lesson_time_step",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="lesson_mode_valid",
        ),
        CheckConstraint(
            "teacher_mode IN ('presence', 'online')",
            name="lesson_teacher_mode_valid",
        ),
        # A teacher at home cannot have a pupil in front of them.
        CheckConstraint(
            "teacher_mode = 'presence' OR mode = 'online'",
            name="lesson_mode_compatible",
        ),
        # Keeps the band CASE expression total.
        CheckConstraint(
            "start_time >= TIME '06:00' AND start_time < TIME '23:00' "
            "AND end_time <= TIME '23:00'",
            name="lesson_within_day",
        ),
        # Bands are half-open: end_time may touch the band's end.
        CheckConstraint(
            "(start_time < TIME '13:00' AND end_time <= TIME '13:00') "
            "OR (start_time >= TIME '13:00' AND start_time < TIME '19:00' "
            "AND end_time <= TIME '19:00') "
            "OR start_time >= TIME '19:00'",
            name="lesson_within_band",
        ),
        # No unique (availability_id, start_time): two pupils at the same hour
        # are two legitimate rows; teacher_occupancy caps the day.
        Index("ix_lesson_day", "date", "band"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Plain Integer: the FK is the composite one above.
    availability_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)

    teacher_mode: Mapped[str] = mapped_column(String(20), nullable=False)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    band: Mapped[str] = mapped_column(
        String(20),
        Computed(_BAND_EXPRESSION, persisted=True),
        nullable=False,
    )

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    availability: Mapped[Availability] = relationship(back_populates="lessons")

    # No room column: the room comes from teacher_room_assignments.
    lesson_bookings: Mapped[list[LessonBooking]] = relationship(
        back_populates="lesson",
        cascade="all, delete-orphan",
        order_by="LessonBooking.booking_id",
    )

    lesson_disciplines: Mapped[list[LessonDiscipline]] = relationship(
        back_populates="lesson",
        cascade="all, delete-orphan",
        order_by="LessonDiscipline.association_subject_id",
    )


# Reads from __dict__, not the attribute: a lazy load cannot do IO under async.
def _related[T](
    session: Session,
    instance: Any,
    *,
    attribute: str,
    model: type[T],
    foreign_key: str,
) -> T | None:
    related = instance.__dict__.get(attribute)

    if related is not None:
        return related

    identifier = getattr(instance, foreign_key)

    return session.get(model, identifier) if identifier is not None else None


def _affected_lessons(session: Session) -> list[Lesson]:
    from app.models.lesson_booking import LessonBooking
    from app.models.lesson_discipline import LessonDiscipline

    affected: dict[int, Lesson] = {
        id(lesson): lesson for lesson in pending_instances(session, Lesson)
    }

    for model in (LessonBooking, LessonDiscipline):
        for child in pending_instances(session, model):
            lesson = _related(
                session,
                child,
                attribute="lesson",
                model=Lesson,
                foreign_key="lesson_id",
            )

            if lesson is not None:
                affected[id(lesson)] = lesson

    return list(affected.values())


# A just-reassigned collection is authoritative: rows a replacement discards
# are not in session.deleted yet, so the database would give the old answer.
def _linked_bookings(
    session: Session,
    lesson: Lesson,
    deleted_link_keys: set[_LinkKey],
) -> list[Any]:
    from app.models.booking import Booking
    from app.models.lesson_booking import LessonBooking

    links = lesson.__dict__.get("lesson_bookings")

    if links is not None:
        resolved = (
            _related(
                session,
                link,
                attribute="booking",
                model=Booking,
                foreign_key="booking_id",
            )
            for link in links
        )

        return [booking for booking in resolved if booking is not None]

    if lesson.id is None:
        return []

    booking_ids = [
        booking_id
        for booking_id in session.scalars(
            select(LessonBooking.booking_id).where(
                LessonBooking.lesson_id == lesson.id,
            ),
        ).all()
        if (lesson.id, booking_id) not in deleted_link_keys
    ]

    return [
        booking
        for booking in (session.get(Booking, booking_id) for booking_id in booking_ids)
        if booking is not None
    ]


def _lesson_disciplines(
    session: Session,
    lesson: Lesson,
    deleted_discipline_keys: set[_LinkKey],
) -> set[int]:
    from app.models.lesson_discipline import LessonDiscipline

    rows = lesson.__dict__.get("lesson_disciplines")

    if rows is not None:
        return {row.association_subject_id for row in rows}

    if lesson.id is None:
        return set()

    return {
        association_subject_id
        for association_subject_id in session.scalars(
            select(LessonDiscipline.association_subject_id).where(
                LessonDiscipline.lesson_id == lesson.id,
            ),
        ).all()
        if (lesson.id, association_subject_id) not in deleted_discipline_keys
    }


# Composite FK columns sync after this hook, so a new lesson's date may only
# exist on the availability in __dict__.
def _lesson_date(lesson: Lesson) -> date | None:
    if lesson.date is not None:
        return lesson.date

    availability = lesson.__dict__.get("availability")

    return availability.date if availability is not None else None


def _deleted_link_keys(session: Session) -> set[_LinkKey]:
    from app.models.lesson_booking import LessonBooking

    return {
        (link.lesson_id, link.booking_id)
        for link in deleted_instances(session, LessonBooking)
    }


def _deleted_discipline_keys(session: Session) -> set[_LinkKey]:
    from app.models.lesson_discipline import LessonDiscipline

    return {
        (row.lesson_id, row.association_subject_id)
        for row in deleted_instances(session, LessonDiscipline)
    }


# Every taught discipline must be requested by some booking and every booking
# must share a discipline with the lesson; full coverage is checked at publish.
@event.listens_for(Session, "before_flush")
def _validate_lesson_disciplines(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.booking_disciplines import disciplines_of

    lessons = _affected_lessons(session)

    if not lessons:
        return

    deleted_link_keys = _deleted_link_keys(session)
    deleted_discipline_keys = _deleted_discipline_keys(session)

    for lesson in lessons:
        bookings = _linked_bookings(session, lesson, deleted_link_keys)

        if not bookings:
            raise ValueError(_LESSON_WITHOUT_BOOKING_ERROR)

        taught = _lesson_disciplines(session, lesson, deleted_discipline_keys)
        requested = [disciplines_of(session, booking) for booking in bookings]

        if not taught:
            # Only a service has no discipline behind it.
            if any(disciplines for disciplines in requested):
                raise ValueError(_LESSON_WITHOUT_DISCIPLINE_ERROR)

            continue

        if not taught <= set().union(*requested):
            raise ValueError(_DISCIPLINE_NOT_REQUESTED_ERROR)

        if any(not (disciplines & taught) for disciplines in requested):
            raise ValueError(_BOOKING_NOT_ON_LESSON_SUBJECT_ERROR)


# mode duplicates the presences' mode and no FK can enforce it; this hook does.
@event.listens_for(Session, "before_flush")
def _validate_lesson_student_mode(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.presence import Presence

    lessons = _affected_lessons(session)

    if not lessons:
        return

    deleted_link_keys = _deleted_link_keys(session)

    for lesson in lessons:
        day = _lesson_date(lesson)

        for booking in _linked_bookings(session, lesson, deleted_link_keys):
            presence = _related(
                session,
                booking,
                attribute="presence",
                model=Presence,
                foreign_key="presence_id",
            )

            if presence is None:
                continue

            if presence.mode != lesson.mode:
                raise ValueError(_MODE_MISMATCH_ERROR)

            if day is not None and presence.date != day:
                raise ValueError(_DATE_MISMATCH_ERROR)
