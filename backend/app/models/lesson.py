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

# The same bounds as app/core/time_band.py, and they have to move with it.
_BAND_EXPRESSION: Final[str] = (
    "CASE WHEN start_time < TIME '13:00' THEN 'MORNING' "
    "WHEN start_time < TIME '19:00' THEN 'AFTERNOON' "
    "ELSE 'EVENING' END"
)

# A (parent id, child id) pair of a link row this flush is removing.
_LinkKey = tuple[Any, Any]


# One hour of teaching: a teacher's offer, the hours it is spent on, and the
# disciplines it covers out of what those hours asked for.
#
# Two modes because they answer different questions. teacher_mode says where the
# teacher is, mode says how the hour reaches the pupils, and a teacher at home
# cannot take a pupil in the room — that asymmetry is lesson_mode_compatible.
#
# date and teacher_mode cannot drift: they are three quarters of a composite
# foreign key. They are on the row because a day is read by day, and an index
# cannot reach across two tables.
#
# RESTRICT and no onupdate: a stored lesson makes its availability neither
# movable nor deletable, so moving it fails loudly instead of dragging the
# lesson to a day nothing has been checked against.
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
        # Subsumes the check above, which stays because it names a different
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
        # A teacher at home cannot have a pupil in front of them.
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
        # Half-open, so the end may touch its band's end: noon to one is all
        # morning. Publishing happens a band at a time.
        CheckConstraint(
            "(start_time < TIME '13:00' AND end_time <= TIME '13:00') "
            "OR (start_time >= TIME '13:00' AND start_time < TIME '19:00' "
            "AND end_time <= TIME '19:00') "
            "OR start_time >= TIME '19:00'",
            name="lesson_within_band",
        ),
        # Deliberately no unique index over (availability_id, start_time): a
        # teacher taking two pupils from two o'clock is two rows with the same
        # availability and start, and no natural key separates that from a
        # double-click. What caps a day is the pupil count in teacher_occupancy.
        Index("ix_lesson_day", "date", "band"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Plain Integer: the foreign key is the composite one above.
    availability_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False)

    teacher_mode: Mapped[str] = mapped_column(String(20), nullable=False)

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    # A pure function of start_time, so the database computes it. Stored
    # because an index is built on it.
    band: Mapped[str] = mapped_column(
        String(20),
        Computed(_BAND_EXPRESSION, persisted=True),
        nullable=False,
    )

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    availability: Mapped[Availability] = relationship(back_populates="lessons")

    # No room here: a room belongs to the teacher for the day, not to the hour.
    # It is read through teacher_room_assignments.

    # Ordered so two reads of the same lesson come back the same way.
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


# A related object as this flush leaves it. Read out of __dict__ and not off the
# attribute: an unloaded attribute would be a lazy load, and under async that
# cannot do IO.
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


# Every lesson this flush says anything about. Keyed by identity, because a
# lesson with no id yet is still one lesson.
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


# The bookings a lesson is teaching, as this flush leaves it. A collection just
# reassigned is the truth: the rows a replacement discards are not in
# session.deleted yet, so the database would give the old answer.
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


# The day a lesson falls on, filled in or not: SQLAlchemy synchronises composite
# foreign key columns after this hook runs, so on a new lesson the availability
# in __dict__ is the only thing that knows.
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


# What a lesson teaches has to be something its pupils asked for, and every
# pupil has to be there for something it teaches. Both directions, which is what
# makes a shared hour legitimate: Latin and Greek with one pupil for each is
# fine, a pupil there for neither is in the wrong room.
#
# That the parts of a request cover all of it cannot be asked here — in a draft
# the second half does not exist — so it is a condition for publishing.
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


# mode is the one denormalisation no foreign key can keep honest: it comes from
# presences three tables away. One hour means all its pupils are in it the same
# way and on the same day.
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
