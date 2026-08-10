from __future__ import annotations

from collections.abc import Callable, Sequence
from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING, Any, Final

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    event,
    select,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.core.time_step import minutes_between
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.flush_state import (
    booking_flush_key,
    deleted_instances,
    new_instances,
    pending_booking_key,
    pending_instances,
    stored_booking_key,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.booking_teacher_preference import BookingTeacherPreference
    from app.models.lesson_booking import LessonBooking
    from app.models.presence import Presence
    from app.models.service import Service
    from app.models.subject_requested import SubjectRequested

_BOOKING_DURATION_EXCEEDS_PRESENCE_ERROR: Final[str] = (
    "La somma delle durate delle prenotazioni supera il tempo dello studente "
    "in quel giorno, in quella modalità"
)

_SUBJECTS_ON_WRONG_KIND_ERROR: Final[str] = (
    "Una richiesta di disciplina singola o di servizio non porta materie "
    "ministeriali"
)

_MINISTRY_REQUEST_WITHOUT_SUBJECTS_ERROR: Final[str] = (
    "Seleziona la materia ministeriale e almeno una disciplina, oppure una "
    "disciplina singola o un servizio"
)

# The most one pupil may spend on one discipline in a day, in one mode.
_MAX_DISCIPLINE_MINUTES_PER_DAY: Final[int] = 120

_DISCIPLINE_OVER_DAILY_LIMIT_ERROR: Final[str] = (
    "Nello stesso giorno e nella stessa modalità uno studente non può "
    "superare le due ore complessive sulla stessa disciplina"
)


class BookingTagEnum(StrEnum):
    ORAL_TEST = "ORAL_TEST"
    WRITTEN_TEST = "WRITTEN_TEST"
    HOMEWORK = "HOMEWORK"
    ENRICHMENT = "ENRICHMENT"
    OUTLINES = "OUTLINES"
    EXAM_PREPARATION = "EXAM_PREPARATION"
    CERTIFICATION = "CERTIFICATION"
    STUDY = "STUDY"


class Booking(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "bookings"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_booking_id"),
        CheckConstraint(
            "duration BETWEEN 30 AND 120 AND duration % 15 = 0",
            name="booking_duration_step",
        ),
        # An hour is asked for in one of three ways: a ministry subject with its
        # disciplines (neither column set), a discipline on its own, or a
        # service. The first two exclude each other here; that the requested
        # subjects belong to the first case only is held by the hook below,
        # because a child table cannot be counted inside a CHECK.
        CheckConstraint(
            "num_nonnulls(association_subject_id, service_name) <= 1",
            name="booking_single_request_kind",
        ),
        # A service has neither a topic nor a kind of test: "study method" is
        # the thing itself, not a lesson about something.
        CheckConstraint(
            "service_name IS NULL OR (cardinality(tags) = 0 AND topic IS NULL)",
            name="booking_service_has_no_tag_or_topic",
        ),
        *not_blank_when_present_constraints("topic", "notes"),
        *no_surrounding_whitespace_constraints("topic", "notes"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    presence_id: Mapped[int] = mapped_column(
        ForeignKey("presences.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    duration: Mapped[int] = mapped_column(Integer, nullable=False)

    # What kind of hour this is: revising for an oral, catching up on homework,
    # going beyond the syllabus. More than one, or none: an hour is often two
    # things at once, and whoever cannot say is still asking for a lesson.
    tags: Mapped[list[BookingTagEnum]] = mapped_column(
        ARRAY(SqlEnum(BookingTagEnum, name="booking_tag_enum")),
        nullable=False,
        default=list,
        server_default="{}",
    )

    # What the lesson is about, in the pupil's own words. A sentence, not an
    # essay.
    topic: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Anything else the teacher should know before the hour starts.
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # A discipline asked for on its own, outside any ministry subject: what a
    # pupil reaches for when what they need is not on their own syllabus. Null
    # on every other kind of request.
    association_subject_id: Mapped[int | None] = mapped_column(
        ForeignKey("association_subjects.id", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=True,
        index=True,
    )

    # Or a service, which is not a subject at all, keyed by its renameable name.
    # Null on every other kind.
    service_name: Mapped[str | None] = mapped_column(
        ForeignKey("services.name", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=True,
        index=True,
    )

    presence: Mapped[Presence] = relationship(back_populates="bookings")

    association_subject: Mapped[AssociationSubject | None] = relationship()

    service: Mapped[Service | None] = relationship()

    subjects_requested: Mapped[list[SubjectRequested]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
    )

    # Ordered by tax code only so the response is stable between reads: the
    # three named on either side are a set, not a ranking.
    teacher_preferences: Mapped[list[BookingTeacherPreference]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingTeacherPreference.teacher_tax_code",
    )

    # No delete-orphan here, and passive_deletes="all" on purpose. Presences are
    # deleted through the ORM — by PresenceService and by the day-closing
    # cleanup — and cascade onto their bookings; a delete-orphan collection
    # would be loaded on the way (which under async raises) and then deleted,
    # quietly stepping around the very restriction that keeps the calendar.
    lesson_bookings: Mapped[list[LessonBooking]] = relationship(
        back_populates="booking",
        passive_deletes="all",
    )


# Every requested hour is exactly one of the three things that can be asked for.
# The table CHECK holds the two mutually exclusive columns; what it cannot see
# is the child table, that is whether the requested subjects are there when they
# are needed and absent when they are not.
#
# New bookings only, and deliberately so. On a stored one the old rows that a
# replacement is discarding are not among the deleted yet when this hook runs:
# counting them would reject a legitimate edit. Edits go through the services,
# which rewrite kind and subjects together.
@event.listens_for(Session, "before_flush")
def _validate_booking_request_kind(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.subject_requested import SubjectRequested

    new_bookings = new_instances(session, Booking)

    if not new_bookings:
        return

    staged: dict[object, int] = {}

    for request in new_instances(session, SubjectRequested):
        key = booking_flush_key(request)

        if key is not None:
            staged[key] = staged.get(key, 0) + 1

    for booking in new_bookings:
        # An unflushed booking is reached by its children through identity; one
        # that already carries an id, through that id.
        count = staged.get(pending_booking_key(booking), 0)

        if booking.id is not None:
            count += staged.get(stored_booking_key(booking.id), 0)

        is_ministry_request = (
            booking.association_subject_id is None and booking.service_name is None
        )

        if is_ministry_request and count == 0:
            raise ValueError(_MINISTRY_REQUEST_WITHOUT_SUBJECTS_ERROR)

        if not is_ministry_request and count > 0:
            raise ValueError(_SUBJECTS_ON_WRONG_KIND_ERROR)


def _resolve_presence(session: Session, booking: Booking) -> Presence | None:
    from app.models.presence import Presence

    if booking.presence is not None:
        return booking.presence

    if booking.presence_id is not None:
        return session.get(Presence, booking.presence_id)

    return None


def _deleted_ids_of(session: Session, model: type[Any]) -> set[Any]:
    return {instance.id for instance in deleted_instances(session, model)}


# Which (student, day, mode) this flush touches — every one of them has to be
# counted again, whether what moved was a stretch of the day or an hour inside
# it.
def _affected_days(
    session: Session,
    pending_presences: Sequence[Any],
    pending_bookings: Sequence[Booking],
) -> set[tuple[str, date, str]]:
    affected = {
        (presence.student_tax_code, presence.date, presence.mode)
        for presence in pending_presences
    }

    for booking in pending_bookings:
        presence = _resolve_presence(session, booking)

        if presence is not None:
            affected.add((presence.student_tax_code, presence.date, presence.mode))

    return affected


def _pending_ids(entities: Sequence[Any]) -> set[Any]:
    return {entity.id for entity in entities if entity.id is not None}


# Pending rows shadow their stored counterparts, deleted ones drop out, and rows
# not yet flushed are keyed by identity so two of them never collapse into one.
def _total_minutes(
    persisted_minutes: dict[Any, int],
    pending: Sequence[Any],
    deleted_ids: set[Any],
    minutes_of: Callable[[Any], int],
) -> int:
    pending_ids = _pending_ids(pending)
    minutes = {
        entity_id: value
        for entity_id, value in persisted_minutes.items()
        if entity_id not in pending_ids and entity_id not in deleted_ids
    }

    for entity in pending:
        key = entity.id if entity.id is not None else id(entity)
        minutes[key] = minutes_of(entity)

    return sum(minutes.values())


@event.listens_for(Session, "before_flush")
def _validate_booking_duration_within_presence(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.presence import Presence

    # Deletions only ever shrink a student's booked/present minutes, so they can
    # never turn a previously valid day invalid: no need to check them.
    #
    # Counted per mode and not per day: an hour of Latin asked online cannot be
    # taught out of the two hours the pupil spends in the building, so the two
    # budgets are two and never lend to each other.
    pending_presences = pending_instances(session, Presence)
    pending_bookings = pending_instances(session, Booking)

    affected = _affected_days(session, pending_presences, pending_bookings)

    if not affected:
        return

    deleted_presence_ids = _deleted_ids_of(session, Presence)
    deleted_booking_ids = _deleted_ids_of(session, Booking)

    for student_tax_code, day, mode in affected:
        # Queried explicitly rather than navigated through relationship
        # collections, so this is correct regardless of whether related objects
        # were built via the relationship or via the raw FK column, and of what
        # else happens to be cached in the identity map.
        persisted_presence_rows = session.execute(
            select(Presence.id, Presence.start_time, Presence.end_time).where(
                Presence.student_tax_code == student_tax_code,
                Presence.date == day,
                Presence.mode == mode,
            ),
        ).all()

        day_presences = [
            presence
            for presence in pending_presences
            if presence.student_tax_code == student_tax_code
            and presence.date == day
            and presence.mode == mode
        ]

        total_presence_minutes = _total_minutes(
            {
                presence_id: minutes_between(start, end)
                for presence_id, start, end in persisted_presence_rows
            },
            day_presences,
            deleted_presence_ids,
            lambda presence: minutes_between(presence.start_time, presence.end_time),
        )

        presence_ids = {
            presence_id for presence_id, _, _ in persisted_presence_rows
        } | _pending_ids(day_presences)

        persisted_booking_rows = (
            session.execute(
                select(Booking.id, Booking.duration).where(
                    Booking.presence_id.in_(presence_ids)
                ),
            ).all()
            if presence_ids
            else []
        )

        day_bookings = [
            booking
            for booking in pending_bookings
            if (presence := _resolve_presence(session, booking)) is not None
            and presence.student_tax_code == student_tax_code
            and presence.date == day
            and presence.mode == mode
        ]

        total_booking_minutes = _total_minutes(
            {
                booking_id: duration
                for booking_id, duration in persisted_booking_rows
            },
            day_bookings,
            deleted_booking_ids,
            lambda booking: booking.duration,
        )

        if total_booking_minutes > total_presence_minutes:
            raise ValueError(_BOOKING_DURATION_EXCEEDS_PRESENCE_ERROR)


def _add_minutes(
    totals: dict[int, int],
    disciplines: set[int],
    duration: int,
) -> None:
    # The whole lesson on each of them: an hour covering three disciplines is an
    # hour of each and not twenty minutes apiece.
    for discipline in disciplines:
        totals[discipline] = totals.get(discipline, 0) + duration


@event.listens_for(Session, "before_flush")
def _validate_discipline_minutes_within_day(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.booking_disciplines import disciplines_of, stored_disciplines
    from app.models.presence import Presence

    # Two hours of one discipline in a day is where a lesson stops teaching and
    # starts filling time. Counted per mode, like the day's own budget: the same
    # discipline asked online is asked of a different day, and the two never lend
    # to each other.
    #
    # Deletions only ever take minutes off a discipline, so they can never turn a
    # valid day invalid: as above, they are not a reason to check.
    pending_presences = pending_instances(session, Presence)
    pending_bookings = pending_instances(session, Booking)

    affected = _affected_days(session, pending_presences, pending_bookings)

    if not affected:
        return

    deleted_booking_ids = _deleted_ids_of(session, Booking)

    for student_tax_code, day, mode in affected:
        persisted_presence_ids = set(
            session.scalars(
                select(Presence.id).where(
                    Presence.student_tax_code == student_tax_code,
                    Presence.date == day,
                    Presence.mode == mode,
                ),
            ).all()
        )

        day_bookings = [
            booking
            for booking in pending_bookings
            if (presence := _resolve_presence(session, booking)) is not None
            and presence.student_tax_code == student_tax_code
            and presence.date == day
            and presence.mode == mode
        ]

        # A booking already in the database is read from it, unless this flush is
        # rewriting it — then what it says now is what counts.
        pending_ids = _pending_ids(day_bookings)

        persisted_rows = (
            session.execute(
                select(Booking.id, Booking.duration).where(
                    Booking.presence_id.in_(persisted_presence_ids),
                ),
            ).all()
            if persisted_presence_ids
            else []
        )

        counted = [
            (booking_id, duration)
            for booking_id, duration in persisted_rows
            if booking_id not in pending_ids and booking_id not in deleted_booking_ids
        ]

        stored = stored_disciplines(
            session,
            [booking_id for booking_id, _ in counted],
        )

        minutes_by_discipline: dict[int, int] = {}

        for booking_id, duration in counted:
            _add_minutes(
                minutes_by_discipline,
                stored.get(booking_id, set()),
                duration,
            )

        for booking in day_bookings:
            # A booking that says nothing about its subjects in this flush is
            # still covering whatever is stored for it.
            _add_minutes(
                minutes_by_discipline,
                disciplines_of(session, booking, stored=stored),
                booking.duration,
            )

        if any(
            minutes > _MAX_DISCIPLINE_MINUTES_PER_DAY
            for minutes in minutes_by_discipline.values()
        ):
            raise ValueError(_DISCIPLINE_OVER_DAILY_LIMIT_ERROR)
