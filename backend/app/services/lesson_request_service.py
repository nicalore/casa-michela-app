from collections.abc import Collection, Iterator, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext, assert_may_book_for
from app.core import booking_close
from app.core.booking_close import assert_still_open, has_closed
from app.core.booking_window import assert_within_booking_window
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale, stale_conflict
from app.core.time_band import TimeBandEnum, band_of, presence_band
from app.core.time_step import fits_a_window, minutes_between
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.presence import Presence
from app.schemas.lesson_request import (
    LessonRequestCreate,
    LessonRequestReplace,
    LessonRequestReplaceMode,
    LessonRequestReplaceSubject,
    LessonRequestSubject,
)
from app.schemas.presence import PresenceCreate
from app.services.booking_service import BookingService
from app.services.collaboration import assert_admin_may_name, resume_collaboration
from app.services.lesson_guard import find_student_day_lessons
from app.services.presence_service import PresenceService
from app.services.pupil_lock import lock_pupil
from app.services.schedule_cascade import unschedule

_CREATE_ERROR: Final[str] = "Errore durante la creazione della richiesta."
_REPLACE_ERROR: Final[str] = "Errore durante l'aggiornamento della richiesta."
_BOOKING_NOT_FOUND_ERROR: Final[str] = "Prenotazione non trovata"
_DAY_LABEL: Final[str] = "la giornata"


# First fit in clock order within the band; if none fits, the roomiest stretch.
def assign_presences(
    presences: list[Presence],
    subjects: Sequence[LessonRequestSubject],
    *,
    taken: Mapping[int, int] | None = None,
) -> Iterator[tuple[Presence, LessonRequestSubject]]:
    ordered = sorted(presences, key=lambda presence: presence.start_time)
    remaining = {
        id(presence): minutes_between(presence.start_time, presence.end_time)
        - (taken or {}).get(id(presence), 0)
        for presence in ordered
    }

    for subject in subjects:
        candidates = [
            presence
            for presence in ordered
            if presence_band(presence.start_time, presence.end_time) == subject.band
        ]

        target = next(
            (
                presence
                for presence in candidates
                if remaining[id(presence)] >= subject.duration
            ),
            None,
        )

        if target is None:
            target = max(candidates, key=lambda presence: remaining[id(presence)])

        remaining[id(target)] -= subject.duration

        yield target, subject


# A change in what is asked takes the lesson off the timetable.
def _shape_of(booking: Booking) -> tuple:
    requested = booking.subjects_requested

    return (
        booking.duration,
        booking.association_subject_id,
        booking.service_name,
        requested[0].ministry_subject_id if requested else None,
        frozenset(row.association_subject_id for row in requested),
    )


def _asked_shape(subject: LessonRequestReplaceSubject) -> tuple:
    return (
        subject.duration,
        subject.association_subject_id,
        subject.service_name,
        subject.ministry_subject_id,
        frozenset(subject.association_subject_ids),
    )


def _band(presence: Presence) -> TimeBandEnum:
    return band_of(presence.start_time)


def _assert_version(
    row: Presence | Booking,
    versions: Mapping[int, datetime],
) -> None:
    if row.id not in versions:
        raise stale_conflict(_DAY_LABEL)

    assert_not_stale(row, versions[row.id], entity_label=_DAY_LABEL)


# Refuses named rows whose band closed after the writer read them.
def _assert_not_frozen(
    identity: IdentityContext,
    plans: list["_ModePlan"],
    presence_ids: Collection[int],
    booking_ids: Collection[int],
) -> None:
    for plan in plans:
        for presence in plan.frozen:
            if presence.id in presence_ids or any(
                booking.id in booking_ids for booking in presence.bookings
            ):
                assert_still_open(
                    plan.payload.date,
                    {_band(presence)},
                    is_admin=identity.overrides_closures,
                )


# Rows added or changed since the read stop the write instead of being deleted.
def _assert_seen(
    identity: IdentityContext,
    payloads: Sequence[LessonRequestReplace],
    plans: list["_ModePlan"],
) -> None:
    presences = {
        row.id: row.expected_updated_at
        for payload in payloads
        for block in payload.modes
        for row in block.dropped_presences
    }
    bookings = {
        row.id: row.expected_updated_at
        for payload in payloads
        for block in payload.modes
        for row in block.dropped_bookings
    }

    _assert_not_frozen(identity, plans, presences, bookings)

    for plan in plans:
        for presence in plan.dropped:
            _assert_version(presence, presences)

        for booking in plan.gone:
            _assert_version(booking, bookings)


@dataclass
class _ModePlan:
    payload: LessonRequestReplace
    block: LessonRequestReplaceMode

    frozen: list[Presence]

    kept: dict[int, Presence] = field(default_factory=dict)
    dropped: list[Presence] = field(default_factory=list)

    # Open subjects stored under these hours; any block may claim them.
    held: dict[int, Booking] = field(default_factory=dict)

    bookings: dict[int, Booking] = field(default_factory=dict)
    gone: list[Booking] = field(default_factory=list)

    final: list[Presence] = field(default_factory=list)

    @property
    def mode(self) -> str:
        return self.block.mode.value

    def final_hours(self) -> list[tuple[str, time, time]]:
        return [
            (self.mode, slot.start_time, slot.end_time) for slot in self.block.slots
        ] + [
            (self.mode, presence.start_time, presence.end_time)
            for presence in self.frozen
        ]


# Owns only the transaction: the services stage uncommitted rows and the
# single commit at the end makes the request all-or-nothing.
class LessonRequestService:
    def __init__(
        self,
        session: AsyncSession,
        presence_service: PresenceService,
        booking_service: BookingService,
    ) -> None:
        self.session = session
        self.presence_service = presence_service
        self.booking_service = booking_service

    async def create(
        self,
        identity: IdentityContext,
        payload: LessonRequestCreate,
    ) -> list[Presence]:
        presences: list[Presence] = []

        async with integrity_guard(self.session, _CREATE_ERROR):
            try:
                await lock_pupil(self.session, payload.student_tax_code)

                # Per mode: each mode has its own bands and hours.
                for block in payload.modes:
                    block_presences = [
                        await self.presence_service.prepare_create(
                            identity,
                            PresenceCreate(
                                date=payload.date,
                                mode=block.mode,
                                start_time=slot.start_time,
                                end_time=slot.end_time,
                                student_tax_code=payload.student_tax_code,
                                booker_tax_code=payload.booker_tax_code,
                            ),
                        )
                        for slot in block.slots
                    ]

                    for presence, subject in assign_presences(
                        block_presences,
                        block.subjects,
                    ):
                        # presence= fills presence.bookings via
                        # back_populates: no further IO for the response.
                        self.session.add(
                            await self.booking_service.build_for_presence(
                                presence,
                                subject,
                            )
                        )

                    presences.extend(block_presences)

                await self.session.flush()
                await self.session.commit()

            except HTTPException:
                # Explicit rollback so the transaction is not held open
                # until the session closes.
                await self.session.rollback()
                raise

        return presences

    # Written in one go and checked once on the result, so it never fails halfway.
    async def replace(
        self,
        identity: IdentityContext,
        payload: LessonRequestReplace,
    ) -> list[Presence]:
        return await self.replace_days(identity, [payload])

    # A subject named in another day or mode than its own moves there.
    async def replace_days(
        self,
        identity: IdentityContext,
        payloads: Sequence[LessonRequestReplace],
    ) -> list[Presence]:
        student_tax_code = payloads[0].student_tax_code
        assert_may_book_for(identity, student_tax_code)
        await assert_admin_may_name(self.session, identity, student_tax_code)

        async with integrity_guard(self.session, _REPLACE_ERROR):
            try:
                await lock_pupil(self.session, student_tax_code)

                plans: list[_ModePlan] = []

                for payload in payloads:
                    stored = await self._day_of(payload)
                    day_plans = [
                        self._plan(identity, payload, block, stored)
                        for block in payload.modes
                    ]

                    await self._check_hours(payload, day_plans, stored)
                    plans.extend(day_plans)

                self._claim(identity, plans)
                _assert_seen(identity, payloads, plans)
                await unschedule(self.session, await self._lessons_to_drop(plans))

                # This order keeps a moving subject off stretches about to go.
                with self.session.no_autoflush:
                    for plan in plans:
                        self._lay(identity, plan)

                    for plan in plans:
                        await self._fill(plan)

                    for plan in plans:
                        for presence in plan.dropped:
                            await self.session.delete(presence)

                await resume_collaboration(self.session, student_tax_code)
                await self.session.flush()
                await self.session.commit()

            except HTTPException:
                await self.session.rollback()
                raise

        return [
            presence
            for payload in payloads
            for presence in await self._day_of(payload, fresh=True)
        ]

    async def _day_of(
        self,
        payload: LessonRequestReplace,
        *,
        fresh: bool = False,
    ) -> list[Presence]:
        return list(
            await self.presence_service.repository.list(
                student_tax_code=payload.student_tax_code,
                booker_tax_code=None,
                date_from=payload.date,
                date_to=payload.date,
                fresh=fresh,
            )
        )

    def _plan(
        self,
        identity: IdentityContext,
        payload: LessonRequestReplace,
        block: LessonRequestReplaceMode,
        stored: list[Presence],
    ) -> _ModePlan:
        assert_still_open(
            payload.date,
            {slot.band for slot in block.slots}
            | {subject.band for subject in block.subjects if subject.band},
            is_admin=identity.overrides_closures,
        )

        now = booking_close.now_in_rome()
        rows = [presence for presence in stored if presence.mode == block.mode.value]
        open_rows = [
            presence
            for presence in rows
            if identity.overrides_closures
            or not has_closed(payload.date, _band(presence), now)
        ]

        plan = _ModePlan(
            payload=payload,
            block=block,
            frozen=[presence for presence in rows if presence not in open_rows],
            held={
                booking.id: booking
                for presence in open_rows
                for booking in presence.bookings
            },
        )

        editable = {presence.id: presence for presence in open_rows}

        for slot in block.slots:
            if slot.presence_id is None:
                continue

            presence = editable.pop(slot.presence_id, None)

            # Closed or deleted since the writer read it.
            if presence is None:
                _assert_not_frozen(identity, [plan], {slot.presence_id}, ())

                raise stale_conflict(_DAY_LABEL)

            assert_not_stale(
                presence,
                slot.expected_updated_at,
                entity_label="la presenza",
            )
            plan.kept[presence.id] = presence

        plan.dropped = list(editable.values())

        return plan

    # Subjects may name any open booking of the request; unnamed ones go.
    def _claim(self, identity: IdentityContext, plans: list[_ModePlan]) -> None:
        owners = {booking_id: plan for plan in plans for booking_id in plan.held}
        claimed: set[int] = set()

        for plan in plans:
            for subject in plan.block.subjects:
                if subject.booking_id is None:
                    continue

                owner = owners.pop(subject.booking_id, None)

                if owner is None and subject.booking_id in claimed:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=_BOOKING_NOT_FOUND_ERROR,
                    )

                if owner is None:
                    _assert_not_frozen(identity, plans, (), {subject.booking_id})

                    raise stale_conflict(_DAY_LABEL)

                claimed.add(subject.booking_id)

                booking = owner.held[subject.booking_id]

                assert_not_stale(
                    booking,
                    subject.expected_updated_at,
                    entity_label="la prenotazione",
                )
                plan.bookings[booking.id] = booking

        for booking_id, owner in owners.items():
            owner.gone.append(owner.held[booking_id])

    async def _check_hours(
        self,
        payload: LessonRequestReplace,
        plans: list[_ModePlan],
        stored: list[Presence],
    ) -> None:
        replaced = {plan.mode for plan in plans}
        others = [
            (presence.mode, presence.start_time, presence.end_time)
            for presence in stored
            if presence.mode not in replaced
        ]
        everything = others + [row for plan in plans for row in plan.final_hours()]

        for plan in plans:
            for slot in plan.block.slots:
                kept = plan.kept.get(slot.presence_id) if slot.presence_id else None
                hours = (slot.start_time, slot.end_time)

                if kept is None:
                    assert_within_booking_window(payload.date)

                elif (kept.start_time, kept.end_time) == hours:
                    continue

                row = (plan.mode, slot.start_time, slot.end_time)
                rest = list(everything)
                rest.remove(row)

                await self.presence_service.assert_fits(
                    payload.date,
                    plan.mode,
                    slot.start_time,
                    slot.end_time,
                    others=rest,
                )

    # Lessons whose subject goes, changes shape or band, or leaves the band's hours.
    async def _lessons_to_drop(self, plans: list[_ModePlan]) -> list[Lesson]:
        dropped: dict[int, Lesson] = {}

        for plan in plans:
            if not plan.kept and not plan.dropped and not plan.frozen:
                continue

            sample = next(
                iter([*plan.kept.values(), *plan.dropped, *plan.frozen]),
            )
            lessons = await find_student_day_lessons(
                self.session,
                student_tax_code=sample.student_tax_code,
                day=sample.date,
                mode=plan.mode,
            )

            if not lessons:
                continue

            links = await self.session.execute(
                select(LessonBooking.lesson_id, LessonBooking.booking_id).where(
                    LessonBooking.lesson_id.in_([lesson.id for lesson in lessons]),
                ),
            )
            bookings_of: dict[int, list[int]] = {}

            for lesson_id, booking_id in links.all():
                bookings_of.setdefault(lesson_id, []).append(booking_id)

            windows: dict[TimeBandEnum, list[tuple[time, time]]] = {}

            for _, start_time, end_time in plan.final_hours():
                windows.setdefault(band_of(start_time), []).append(
                    (start_time, end_time),
                )

            gone = {booking.id for booking in plan.gone}
            band_of_booking = {
                booking.id: _band(presence)
                for presence in plan.frozen
                for booking in presence.bookings
            }
            reshaped: set[int] = set()

            for subject in plan.block.subjects:
                booking = plan.bookings.get(subject.booking_id or 0)

                if booking is None:
                    continue

                band_of_booking[booking.id] = subject.band

                if (
                    _shape_of(booking) != _asked_shape(subject)
                    or _band(booking.presence) != subject.band
                ):
                    reshaped.add(booking.id)

            for lesson in lessons:
                for booking_id in bookings_of.get(lesson.id, []):
                    band = band_of_booking.get(booking_id)

                    if (
                        booking_id in gone
                        or booking_id in reshaped
                        or band is None
                        or not fits_a_window(
                            lesson.start_time,
                            lesson.end_time,
                            windows.get(band, []),
                        )
                    ):
                        dropped[lesson.id] = lesson

        return list(dropped.values())

    def _lay(self, identity: IdentityContext, plan: _ModePlan) -> None:
        payload = plan.payload
        booker = self.presence_service.resolve_booker(identity, payload.booker_tax_code)

        for slot in plan.block.slots:
            presence = plan.kept.get(slot.presence_id) if slot.presence_id else None

            if presence is None:
                presence = Presence(
                    student_tax_code=payload.student_tax_code,
                    booker_tax_code=booker,
                    date=payload.date,
                    mode=plan.mode,
                    start_time=slot.start_time,
                    end_time=slot.end_time,
                    bookings=[],
                )
                self.session.add(presence)

            presence.start_time = slot.start_time
            presence.end_time = slot.end_time
            plan.final.append(presence)

        plan.final.sort(key=lambda presence: presence.start_time)

    async def _fill(self, plan: _ModePlan) -> None:
        final = plan.final

        for booking in plan.gone:
            await self.session.delete(booking)

        taken: dict[int, int] = {}
        new_subjects: list[LessonRequestReplaceSubject] = []

        for subject in plan.block.subjects:
            booking = plan.bookings.get(subject.booking_id or 0)

            if booking is None:
                new_subjects.append(subject)

                continue

            await self.booking_service.fill(booking, subject)

            if booking.presence not in final or _band(booking.presence) != subject.band:
                booking.presence = next(
                    presence for presence in final if _band(presence) == subject.band
                )

            key = id(booking.presence)
            taken[key] = taken.get(key, 0) + booking.duration

        for presence, subject in assign_presences(final, new_subjects, taken=taken):
            self.session.add(
                await self.booking_service.build_for_presence(presence, subject),
            )
