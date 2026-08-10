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
    "Una lezione deve contenere almeno una prenotazione"
)

_DISCIPLINE_NOT_REQUESTED_ERROR: Final[str] = (
    "Ogni disciplina della lezione deve essere richiesta da almeno una delle "
    "prenotazioni collegate"
)

_BOOKING_NOT_ON_LESSON_SUBJECT_ERROR: Final[str] = (
    "Ogni prenotazione collegata deve avere almeno una disciplina in comune con "
    "la lezione"
)

_LESSON_WITHOUT_DISCIPLINE_ERROR: Final[str] = (
    "Una lezione senza discipline può contenere solo richieste di servizio"
)

_MODE_MISMATCH_ERROR: Final[str] = (
    "Tutte le prenotazioni di una lezione devono essere nella stessa modalità "
    "della lezione"
)

_DATE_MISMATCH_ERROR: Final[str] = (
    "Le prenotazioni di una lezione devono essere nello stesso giorno della lezione"
)

# The band bounds, written the way Postgres wants them for a generated column.
# They say the same thing as app/core/time_band.py and have to move with it.
_BAND_EXPRESSION: Final[str] = (
    "CASE WHEN start_time < TIME '13:00' THEN 'MORNING' "
    "WHEN start_time < TIME '19:00' THEN 'AFTERNOON' "
    "ELSE 'EVENING' END"
)


# One hour of teaching: a teacher's offer, the requested hours it is spent on,
# and the disciplines it covers out of everything those hours asked for.
#
# Two modes, and the difference between them is the point. teacher_mode says
# where the teacher is, and comes from the availability; mode says how the hour
# reaches the pupils, and comes from their presences. A teacher in the building
# teaches both the pupils in front of them and the ones on a screen; a teacher
# at home can only do the latter. That asymmetry is the CHECK below, and it is
# the reason the two are separate columns rather than one.
#
# date and teacher_mode are not a copy that can drift: they are three quarters
# of a composite foreign key, and the database rejects any row that does not
# match the availability the lesson hangs off. They are on the row because the
# calendar of a day is read by day, and because an index cannot reach across two
# tables. It is the same arrangement subjects_requested uses.
#
# The foreign key restricts rather than cascades: the calendar is kept as a
# record, so a stored lesson makes its availability neither movable nor
# deletable. Without onupdate, moving that availability fails loudly instead of
# dragging the lesson to a day where nothing has been checked.
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
        # Half an hour is the shortest stretch worth teaching in. Logically this
        # subsumes the check above, which stays because it names a different
        # mistake.
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
        # A teacher at a screen at home cannot have a pupil sitting in front of
        # them; a teacher in the building can do either.
        CheckConstraint(
            "teacher_mode = 'presence' OR mode = 'online'",
            name="lesson_mode_compatible",
        ),
        # What makes the CASE of the generated column total.
        CheckConstraint(
            "start_time >= TIME '06:00' AND start_time < TIME '23:00' "
            "AND end_time <= TIME '23:00'",
            name="lesson_within_day",
        ),
        # A lesson belongs to one part of the day. The end is allowed to touch
        # its band's end because the bands are half-open: noon to one is all
        # morning. Publishing happens a band at a time, and half a lesson
        # published says nothing to anybody.
        CheckConstraint(
            "(start_time < TIME '13:00' AND end_time <= TIME '13:00') "
            "OR (start_time >= TIME '13:00' AND start_time < TIME '19:00' "
            "AND end_time <= TIME '19:00') "
            "OR start_time >= TIME '19:00'",
            name="lesson_within_band",
        ),
        # Two lessons on one availability starting at the same minute are one
        # lesson entered twice.
        Index("ux_lesson_slot", "availability_id", "start_time", unique=True),
        Index("ix_lesson_day", "date", "band"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Plain Integer and not ForeignKey: the foreign key is the composite one
    # above, and declaring a single-column one as well would make two of them
    # towards the same table.
    availability_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)

    teacher_mode: Mapped[str] = mapped_column(String(20), nullable=False)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    # Computed by the database rather than written by the application: it is a
    # pure function of start_time, and this way it cannot be wrong. Stored
    # because an index is built on it and the whole publication turns on it.
    band: Mapped[str] = mapped_column(
        String(20),
        Computed(_BAND_EXPRESSION, persisted=True),
        nullable=False,
    )

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    availability: Mapped[Availability] = relationship(back_populates="lessons")

    # No room here on purpose: a room belongs to the teacher for the day, not to
    # the hour. Which one a lesson happens in is read through
    # teacher_room_assignments, and several teachers share one.

    # Ordered so that two reads of the same lesson come back the same way.
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


# Every lesson this flush says anything about: the ones being written, plus the
# ones reached through a link or a discipline being written. Keyed by identity,
# because a lesson that has no id yet is still one lesson.
def _affected_lessons(session: Session) -> list[Lesson]:
    from app.models.lesson_booking import LessonBooking
    from app.models.lesson_discipline import LessonDiscipline

    affected: dict[int, Lesson] = {
        id(lesson): lesson for lesson in pending_instances(session, Lesson)
    }

    for model in (LessonBooking, LessonDiscipline):
        for child in pending_instances(session, model):
            lesson = child.__dict__.get("lesson")

            if lesson is None and child.lesson_id is not None:
                lesson = session.get(Lesson, child.lesson_id)

            if lesson is not None:
                affected[id(lesson)] = lesson

    return list(affected.values())


# The bookings a lesson is teaching, as this flush leaves it.
#
# The collection is read out of __dict__ and not off the attribute: where a
# service has just reassigned it, that is the truth, because the rows a
# replacement discards are not in session.deleted yet when this runs, and
# reading the database would give the old answer. Where nothing was assigned,
# the attribute would be an unloaded collection, and touching it under async is
# a lazy load in a place that cannot do IO.
def _linked_bookings(
    session: Session,
    lesson: Lesson,
    deleted_link_keys: set[tuple[Any, Any]],
) -> list[Any]:
    from app.models.booking import Booking
    from app.models.lesson_booking import LessonBooking

    links = lesson.__dict__.get("lesson_bookings")

    if links is not None:
        resolved = []

        for link in links:
            booking = link.__dict__.get("booking")

            if booking is None and link.booking_id is not None:
                booking = session.get(Booking, link.booking_id)

            if booking is not None:
                resolved.append(booking)

        return resolved

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
    deleted_discipline_keys: set[tuple[Any, Any]],
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


# The day a lesson falls on, whether or not its column has been filled in yet.
#
# Assigning the availability object does not populate date and teacher_mode
# straight away: SQLAlchemy synchronises the columns of a composite foreign key
# while the flush is being processed, which is after this hook has run. So on a
# brand-new lesson the column is still None and the availability in __dict__ is
# the only thing that knows.
def lesson_date(lesson: Lesson) -> date | None:
    if lesson.date is not None:
        return lesson.date

    availability = lesson.__dict__.get("availability")

    return availability.date if availability is not None else None


def _deleted_link_keys(session: Session) -> set[tuple[Any, Any]]:
    from app.models.lesson_booking import LessonBooking

    return {
        (link.lesson_id, link.booking_id)
        for link in deleted_instances(session, LessonBooking)
    }


# What a lesson teaches has to be something its pupils asked for, and every
# pupil in it has to be there for something it teaches.
#
# The rule works in both directions, and the pair is what makes a shared hour
# legitimate: a lesson on Latin and Greek where one pupil is there for Latin and
# the other for Greek is fine, while a pupil whose request has nothing to do
# with either is in the wrong room.
#
# The parts of one request may overlap rather than divide: two teachers taking
# turns on the same discipline is a real arrangement. That their union is
# exactly what was asked for cannot be required here — in a draft the second
# half does not exist yet — so it is a condition for publishing instead.
@event.listens_for(Session, "before_flush")
def _validate_lesson_disciplines(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.booking_disciplines import disciplines_of
    from app.models.lesson_discipline import LessonDiscipline

    lessons = _affected_lessons(session)

    if not lessons:
        return

    deleted_link_keys = _deleted_link_keys(session)
    deleted_discipline_keys = {
        (row.lesson_id, row.association_subject_id)
        for row in deleted_instances(session, LessonDiscipline)
    }

    for lesson in lessons:
        bookings = _linked_bookings(session, lesson, deleted_link_keys)

        if not bookings:
            raise ValueError(_LESSON_WITHOUT_BOOKING_ERROR)

        taught = _lesson_disciplines(session, lesson, deleted_discipline_keys)
        requested = [disciplines_of(session, booking) for booking in bookings]

        if not taught:
            # Only a service has no discipline behind it, so an hour on nothing
            # in particular can hold nothing else.
            if any(disciplines for disciplines in requested):
                raise ValueError(_LESSON_WITHOUT_DISCIPLINE_ERROR)

            continue

        if not taught <= set().union(*requested):
            raise ValueError(_DISCIPLINE_NOT_REQUESTED_ERROR)

        if any(not (disciplines & taught) for disciplines in requested):
            raise ValueError(_BOOKING_NOT_ON_LESSON_SUBJECT_ERROR)


# mode is the one denormalisation no foreign key can keep honest: it comes from
# the presences of the linked bookings, which are three tables away. A lesson is
# one hour for the pupils in it, so they are all in it the same way and on the
# same day.
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
        day = lesson_date(lesson)

        for booking in _linked_bookings(session, lesson, deleted_link_keys):
            presence = booking.__dict__.get("presence")

            if presence is None and booking.presence_id is not None:
                presence = session.get(Presence, booking.presence_id)

            if presence is None:
                continue

            if presence.mode != lesson.mode:
                raise ValueError(_MODE_MISMATCH_ERROR)

            if day is not None and presence.date != day:
                raise ValueError(_DATE_MISMATCH_ERROR)
