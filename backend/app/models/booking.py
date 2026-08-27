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
    "La somma delle durate delle prenotazioni supera la presenza dello studente per "
    "quel giorno in quella modalità"
)

_SUBJECTS_ON_WRONG_KIND_ERROR: Final[str] = (
    "Una richiesta di disciplina singola o di servizio non ha materie ministeriali"
)

_MINISTRY_REQUEST_WITHOUT_SUBJECTS_ERROR: Final[str] = (
    "Seleziona la materia ministeriale e almeno una disciplina, oppure una "
    "disciplina singola o un servizio"
)

# Max minutes per student per discipline per day, per mode.
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
        # Both columns null means a ministry-subject request; the child-table
        # side is enforced by the hook below, since a CHECK cannot count rows.
        CheckConstraint(
            "num_nonnulls(association_subject_id, service_name) <= 1",
            name="booking_single_request_kind",
        ),
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

    tags: Mapped[list[BookingTagEnum]] = mapped_column(
        ARRAY(SqlEnum(BookingTagEnum, name="booking_tag_enum")),
        nullable=False,
        default=list,
        server_default="{}",
    )

    topic: Mapped[str | None] = mapped_column(String(255), nullable=True)

    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    # Set only for a standalone-discipline request.
    association_subject_id: Mapped[int | None] = mapped_column(
        ForeignKey("association_subjects.id", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=True,
        index=True,
    )

    # Set only for a service request.
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

    teacher_preferences: Mapped[list[BookingTeacherPreference]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingTeacherPreference.teacher_tax_code",
    )

    # No delete-orphan on purpose: it would lazy-load (raises under async) and
    # delete around the RESTRICT that protects the calendar.
    lesson_bookings: Mapped[list[LessonBooking]] = relationship(
        back_populates="booking",
        passive_deletes="all",
    )


# New bookings only: on a stored one a replacement's discarded rows are not in
# session.deleted yet, and edits go through the services anyway.
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


# Pending rows shadow stored ones; unflushed rows are keyed by identity so two
# never collapse into one.
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

    # Counted per mode: the online and in-presence budgets never lend to each
    # other. Deletions alone can never invalidate a day.
    pending_presences = pending_instances(session, Presence)
    pending_bookings = pending_instances(session, Booking)

    affected = _affected_days(session, pending_presences, pending_bookings)

    if not affected:
        return

    deleted_presence_ids = _deleted_ids_of(session, Presence)
    deleted_booking_ids = _deleted_ids_of(session, Booking)

    for student_tax_code, day, mode in affected:
        # Queried explicitly so the result does not depend on what the identity
        # map happens to have cached.
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
    # An hour covering N disciplines counts as a full hour of each.
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
            # A booking silent about its subjects still covers its stored ones.
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
