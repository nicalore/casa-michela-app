from __future__ import annotations

from collections.abc import Sequence
from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING, Any, Final

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    event,
    inspect,
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
    from app.models.booking_preferred_teacher import BookingPreferredTeacher
    from app.models.lesson_booking import LessonBooking
    from app.models.presence import Presence
    from app.models.service import Service
    from app.models.subject_requested import SubjectRequested

_BOOKING_DURATION_EXCEEDS_PRESENCE_ERROR: Final[str] = (
    "La somma delle durate delle prenotazioni supera la presenza dello studente in "
    "quella fascia oraria e in quella modalità"
)

_SUBJECTS_ON_WRONG_KIND_ERROR: Final[str] = (
    "Una richiesta di disciplina singola o di servizio non ha materie ministeriali"
)

_MINISTRY_REQUEST_WITHOUT_SUBJECTS_ERROR: Final[str] = (
    "Seleziona la materia ministeriale e almeno una disciplina, oppure una "
    "disciplina singola o un servizio"
)

# Session info key: stretches the association's own sweeps take away.
_SWEPT_KEY: Final[str] = "swept_presence_ids"

# Max minutes per student per discipline in one band of a day, per mode.
_MAX_DISCIPLINE_MINUTES_PER_BAND: Final[int] = 120

_DISCIPLINE_OVER_BAND_LIMIT_ERROR: Final[str] = (
    "Nella stessa fascia oraria uno studente non può superare le due ore "
    "complessive sulla stessa disciplina"
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

    preferred_teachers: Mapped[list[BookingPreferredTeacher]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingPreferredTeacher.teacher_tax_code",
    )

    # No delete-orphan on purpose: it would lazy-load (raises under async) and
    # delete around the RESTRICT that protects the calendar.
    lesson_bookings: Mapped[list[LessonBooking]] = relationship(
        back_populates="booking",
        passive_deletes="all",
    )


# Swept stretches (openings changed, pupil left) go even if their band falls short.
def mark_swept(session: Session, presence: Presence) -> None:
    session.info.setdefault(_SWEPT_KEY, set()).add(presence.id)


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


# A stretch moved to another day, mode or band leaves its old day short too.
def _days_of(presence: Any) -> set[tuple[str, date, str]]:
    state = inspect(presence)

    def before(name: str) -> Any:
        deleted = state.attrs[name].history.deleted

        return deleted[0] if deleted else getattr(presence, name)

    return {
        (presence.student_tax_code, presence.date, presence.mode),
        (before("student_tax_code"), before("date"), before("mode")),
    }


def _affected_days(
    session: Session,
    pending_presences: Sequence[Any],
    pending_bookings: Sequence[Booking],
) -> set[tuple[str, date, str]]:
    affected = {
        day for presence in pending_presences for day in _days_of(presence)
    }

    for booking in pending_bookings:
        presence = _resolve_presence(session, booking)

        if presence is not None:
            affected.add((presence.student_tax_code, presence.date, presence.mode))

    return affected


def _pending_ids(entities: Sequence[Any]) -> set[Any]:
    return {entity.id for entity in entities if entity.id is not None}


def _entity_key(entity: Any) -> Any:
    return entity.id if entity.id is not None else id(entity)


def _day_of(presence: Any) -> tuple[str, date, str]:
    return (presence.student_tax_code, presence.date, presence.mode)


@event.listens_for(Session, "before_flush")
def _validate_booking_duration_within_presence(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.core.time_band import band_of
    from app.models.presence import Presence

    # Per mode and band: neither lends minutes to another.
    # Pending rows shadow stored ones; unflushed rows are keyed by identity.
    pending_presences = pending_instances(session, Presence)
    pending_bookings = pending_instances(session, Booking)

    # Any stretch going away may leave its band short; sweeps are exempt.
    swept = session.info.get(_SWEPT_KEY, set())
    affected = _affected_days(session, pending_presences, pending_bookings) | {
        day
        for presence in deleted_instances(session, Presence)
        if presence.id not in swept
        for day in _days_of(presence)
    }

    if not affected:
        return

    shadowed_presence_ids = _deleted_ids_of(session, Presence) | _pending_ids(
        pending_presences,
    )
    shadowed_booking_ids = _deleted_ids_of(session, Booking) | _pending_ids(
        pending_bookings,
    )

    for affected_day in affected:
        student_tax_code, day, mode = affected_day

        # Queried explicitly: the result must not depend on the identity map's cache.
        stored_presences = session.execute(
            select(Presence.id, Presence.start_time, Presence.end_time).where(
                Presence.student_tax_code == student_tax_code,
                Presence.date == day,
                Presence.mode == mode,
            ),
        ).all()

        minutes_of: dict[Any, int] = {}
        band_by_presence: dict[Any, Any] = {}

        for presence_id, start_time, end_time in stored_presences:
            if presence_id in shadowed_presence_ids:
                continue

            minutes_of[presence_id] = minutes_between(start_time, end_time)
            band_by_presence[presence_id] = band_of(start_time)

        for presence in pending_presences:
            if _day_of(presence) == affected_day:
                key = _entity_key(presence)
                minutes_of[key] = minutes_between(
                    presence.start_time,
                    presence.end_time,
                )
                band_by_presence[key] = band_of(presence.start_time)

        # A stretch moved onto this day keeps its stored bookings.
        stored_ids = {presence_id for presence_id, _, _ in stored_presences} | {
            presence.id
            for presence in pending_presences
            if presence.id is not None and _day_of(presence) == affected_day
        }
        stored_bookings = (
            session.execute(
                select(Booking.id, Booking.duration, Booking.presence_id).where(
                    Booking.presence_id.in_(stored_ids),
                ),
            ).all()
            if stored_ids
            else []
        )

        asked: dict[Any, int] = {}
        offered: dict[Any, int] = {}

        for key, minutes in minutes_of.items():
            band = band_by_presence[key]
            offered[band] = offered.get(band, 0) + minutes

        for booking_id, duration, presence_id in stored_bookings:
            if booking_id in shadowed_booking_ids:
                continue

            band = band_by_presence.get(presence_id)

            if band is not None:
                asked[band] = asked.get(band, 0) + duration

        for booking in pending_bookings:
            presence = _resolve_presence(session, booking)

            if presence is None or _day_of(presence) != affected_day:
                continue

            band = band_by_presence.get(_entity_key(presence))

            if band is not None:
                asked[band] = asked.get(band, 0) + booking.duration

        if any(minutes > offered.get(band, 0) for band, minutes in asked.items()):
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
    from app.core.time_band import band_of
    from app.models.booking_disciplines import disciplines_of, stored_disciplines
    from app.models.presence import Presence

    pending_presences = pending_instances(session, Presence)
    pending_bookings = pending_instances(session, Booking)

    affected = _affected_days(session, pending_presences, pending_bookings)

    if not affected:
        return

    deleted_booking_ids = _deleted_ids_of(session, Booking)
    deleted_presence_ids = _deleted_ids_of(session, Presence)
    # Every pending booking counts where it sits now, not where it is stored.
    pending_booking_ids = _pending_ids(pending_bookings)
    # Moved stretches count on their new day, with their bookings.
    moved_to = {
        presence.id: _day_of(presence)
        for presence in pending_presences
        if presence.id is not None
    }

    for affected_day in affected:
        student_tax_code, day, mode = affected_day
        persisted_presence_ids = {
            presence_id
            for presence_id in session.scalars(
                select(Presence.id).where(
                    Presence.student_tax_code == student_tax_code,
                    Presence.date == day,
                    Presence.mode == mode,
                ),
            ).all()
            if presence_id not in deleted_presence_ids
            and moved_to.get(presence_id, affected_day) == affected_day
        } | {
            presence_id
            for presence_id, target in moved_to.items()
            if target == affected_day
        }

        day_bookings = [
            booking
            for booking in pending_bookings
            if (presence := _resolve_presence(session, booking)) is not None
            and presence.student_tax_code == student_tax_code
            and presence.date == day
            and presence.mode == mode
        ]

        persisted_rows = (
            session.execute(
                select(Booking.id, Booking.duration, Booking.presence_id).where(
                    Booking.presence_id.in_(persisted_presence_ids),
                ),
            ).all()
            if persisted_presence_ids
            else []
        )

        # A moved stretch counts in its new band.
        band_by_presence = {
            presence_id: band_of(start_time)
            for presence_id, start_time in (
                session.execute(
                    select(Presence.id, Presence.start_time).where(
                        Presence.id.in_(persisted_presence_ids),
                    ),
                ).all()
                if persisted_presence_ids
                else []
            )
        }

        for presence in pending_presences:
            if presence.id in band_by_presence:
                band_by_presence[presence.id] = band_of(presence.start_time)

        counted = [
            (booking_id, duration, band_by_presence.get(presence_id))
            for booking_id, duration, presence_id in persisted_rows
            if booking_id not in pending_booking_ids
            and booking_id not in deleted_booking_ids
        ]

        stored = stored_disciplines(
            session,
            [booking_id for booking_id, _, _ in counted],
        )

        minutes_by_band: dict[Any, dict[int, int]] = {}

        for booking_id, duration, band in counted:
            _add_minutes(
                minutes_by_band.setdefault(band, {}),
                stored.get(booking_id, set()),
                duration,
            )

        for booking in day_bookings:
            presence = _resolve_presence(session, booking)

            # A booking silent about its subjects still covers its stored ones.
            _add_minutes(
                minutes_by_band.setdefault(band_of(presence.start_time), {}),
                disciplines_of(session, booking, stored=stored),
                booking.duration,
            )

        if any(
            minutes > _MAX_DISCIPLINE_MINUTES_PER_BAND
            for totals in minutes_by_band.values()
            for minutes in totals.values()
        ):
            raise ValueError(_DISCIPLINE_OVER_BAND_LIMIT_ERROR)
