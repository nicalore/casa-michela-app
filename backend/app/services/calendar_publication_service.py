from collections import defaultdict
from collections.abc import Callable, Sequence
from datetime import date, datetime, timedelta
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import func

from app.api.rbac import IdentityContext
from app.core.booking_close import assert_ready_to_publish, has_closed, now_in_rome
from app.core.i18n import request_language, tr
from app.core.integrity import integrity_guard
from app.core.labels import time_band_label
from app.core.time_band import TimeBandEnum, band_bounds, band_of
from app.core.time_step import minutes_between
from app.models.booking_disciplines import loaded_disciplines
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.person import GenderEnum
from app.repositories.booking_repository import BookingRepository
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.calendar_band_lock_repository import (
    CalendarBandLockRepository,
)
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.calendar_teacher_exclusion_repository import (
    CalendarTeacherExclusionRepository,
)
from app.repositories.calendar_teacher_note_repository import (
    CalendarTeacherNoteRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.presence_repository import PresenceRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import CalendarPublicationCreate
from app.services.bilingual import Bilingual, by_count
from app.services.calendar_freeze import (
    assert_not_confirmed,
    assert_started_unchanged,
    started_rows,
)
from app.services.calendar_snapshot import differs, restore, snapshot_of
from app.services.lesson_guard import assert_band_claimed
from app.services.room_occupancy import (
    capacity_warnings,
    rooms_left_open,
    teachers_adrift,
    teachers_in_building,
)
from app.services.room_supervision_service import realign_shifts

_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Questo calendario non è pubblicato.",
    "This calendar is not published.",
)
_NOT_IN_DRAFT_ERROR: Final[Bilingual] = Bilingual(
    "Questo calendario non è in bozza.",
    "This calendar is not in draft.",
)
_ALREADY_IN_DRAFT_ERROR: Final[Bilingual] = Bilingual(
    "Questo calendario è già in bozza.",
    "This calendar is already in draft.",
)
_STARTED_UNPUBLISH_ERROR: Final[Bilingual] = Bilingual(
    "Le lezioni di questa fascia sono già cominciate: "
    "il calendario non si può più ritirare.",
    "The lessons of this time slot have already started: "
    "the calendar can no longer be withdrawn.",
)
_PUBLISH_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante la pubblicazione.",
    "Something went wrong while publishing.",
)
_DISCARD_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante l'uscita dalla bozza.",
    "Something went wrong while leaving the draft.",
)

_ALREADY_PUBLISHED_ERROR: Final[Bilingual] = Bilingual(
    "Il calendario del {day} ({band}) è già pubblicato.",
    "The calendar for {day} ({band}) is already published.",
)

# Each pair: one listed, then several.
_PARTIAL_COVERAGE_ERRORS: Final[tuple[Bilingual, Bilingual]] = (
    Bilingual(
        "Una prenotazione è coperta solo in parte: {students}. Completa o "
        "rimuovi le lezioni prima di pubblicare.",
        "A booking is only partly covered: {students}. Complete or remove "
        "the lessons before publishing.",
    ),
    Bilingual(
        "Alcune prenotazioni sono coperte solo in parte: {students}. Completa o "
        "rimuovi le lezioni prima di pubblicare.",
        "Some bookings are only partly covered: {students}. Complete or remove "
        "the lessons before publishing.",
    ),
)

_UNCOVERED_DISCIPLINES_ERRORS: Final[tuple[Bilingual, Bilingual]] = (
    Bilingual(
        "Una disciplina richiesta non è assegnata a nessuna lezione: {students}.",
        "A requested discipline is not assigned to any lesson: {students}.",
    ),
    Bilingual(
        "Alcune discipline richieste non sono assegnate a nessuna lezione: "
        "{students}.",
        "Some requested disciplines are not assigned to any lesson: {students}.",
    ),
)

_UNPLANNED_ERRORS: Final[tuple[Bilingual, Bilingual]] = (
    Bilingual(
        "Una prenotazione non è stata pianificata: {students}. Mettila in "
        "calendario o annullala prima di pubblicare.",
        "A booking has not been planned: {students}. Put it in the calendar "
        "or cancel it before publishing.",
    ),
    Bilingual(
        "Alcune prenotazioni non sono state pianificate: {students}. Mettile in "
        "calendario o annullale prima di pubblicare.",
        "Some bookings have not been planned: {students}. Put them in the "
        "calendar or cancel them before publishing.",
    ),
)

_UNASSIGNED_ACTIVITIES_ERRORS: Final[tuple[Bilingual, Bilingual]] = (
    Bilingual(
        "Un'attività non è stata assegnata a nessun docente: {names}. "
        "Assegnala o eliminala prima di pubblicare.",
        "An activity has not been assigned to any teacher: {names}. "
        "Assign it or delete it before publishing.",
    ),
    Bilingual(
        "Alcune attività non sono state assegnate a nessun docente: {names}. "
        "Assegnale o eliminale prima di pubblicare.",
        "Some activities have not been assigned to any teacher: {names}. "
        "Assign them or delete them before publishing.",
    ),
)

_TEACHER_WITHOUT_A_ROOM_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Un docente in presenza non ha una stanza assegnata: {teachers}.",
        "A teacher in person has no room assigned: {teachers}.",
    ),
    GenderEnum.F: Bilingual(
        "Una docente in presenza non ha una stanza assegnata: {teachers}.",
        "A teacher in person has no room assigned: {teachers}.",
    ),
}

# Feminine only when every teacher listed is a woman.
_TEACHERS_WITHOUT_A_ROOM_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Alcuni docenti in presenza non hanno una stanza assegnata: {teachers}.",
        "Some teachers in person have no room assigned: {teachers}.",
    ),
    GenderEnum.F: Bilingual(
        "Alcune docenti in presenza non hanno una stanza assegnata: {teachers}.",
        "Some teachers in person have no room assigned: {teachers}.",
    ),
}

_ROOMS_LEFT_OPEN_ERRORS: Final[tuple[Bilingual, Bilingual]] = (
    Bilingual(
        "Una stanza non ha un responsabile per tutte le ore di lezione: {rooms}.",
        "A room has no supervisor for all its lesson hours: {rooms}.",
    ),
    Bilingual(
        "Alcune stanze non hanno un responsabile per tutte le ore di lezione: "
        "{rooms}.",
        "Some rooms have no supervisor for all their lesson hours: {rooms}.",
    ),
)

_NOT_YOURS_TO_DISCARD_ERROR: Final[Bilingual] = Bilingual(
    "La bozza è stata aperta da {opener}: uscendone si annullerebbe anche il "
    "suo lavoro. Puoi pubblicarla, oppure chiedere a {opener} di uscirne.",
    "The draft was opened by {opener}: leaving it would also undo their "
    "work. You can publish it, or ask {opener} to leave it.",
)

_MAX_NAMED: Final[int] = 5

# A calendar asks for one day; this bounds what a single request may scan.
_MAX_UNBOOKED_DAYS: Final[int] = 62


def _person_label(person: object) -> str:
    first = getattr(person, "first_name", "") or ""
    last = getattr(person, "last_name", "") or ""

    return f"{first} {last}".strip()


def _by_count(errors: tuple[Bilingual, Bilingual], count: int) -> str:
    return by_count(errors, count).for_request()


def _joined(names: Sequence[str]) -> str:
    shown = sorted(names)[:_MAX_NAMED]
    rest = len(names) - len(shown)
    more = tr(f" e altri {rest}", f" and {rest} more")

    return ", ".join(shown) + (more if rest > 0 else "")


class CalendarPublicationService:
    def __init__(
        self,
        repository: CalendarPublicationRepository,
        lessons: LessonRepository,
        assignments: TeacherRoomAssignmentRepository,
        supervisions: RoomSupervisionRepository,
        rooms: RoomRepository,
        now: Callable[[], datetime] = now_in_rome,
    ) -> None:
        self.repository = repository
        self.lessons = lessons
        self.assignments = assignments
        self.supervisions = supervisions
        self.rooms = rooms
        self.now = now

    @property
    def session(self):  # noqa: ANN201 - mirrors the other services
        return self.repository.session

    # Coverage checks below read requests through their lessons, so a request on
    # no lesson at all must be caught here.
    async def _assert_nothing_left_out(self, day: date, band: str) -> None:
        start_time, end_time = band_bounds(TimeBandEnum(band))

        left_out = await BookingRepository(self.session).find_unplanned_students(
            day,
            start_time,
            end_time,
        )

        if not left_out:
            return

        people = await PersonRepository(self.session).get_options(left_out)

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_by_count(_UNPLANNED_ERRORS, len(left_out)).format(
                students=_joined(
                    [_person_label(people.get(code)) for code in set(left_out)],
                ),
            ),
        )

    async def _assert_requests_covered(
        self,
        day: date,
        band: str,
        lessons: Sequence[Lesson],
    ) -> None:
        await self._assert_nothing_left_out(day, band)

        bookings = {
            link.booking.id: link.booking
            for lesson in lessons
            for link in lesson.lesson_bookings
        }

        if not bookings:
            return

        links = await self.lessons.list_links_for_bookings(list(bookings))
        lesson_ids = {lesson_id for _, lesson_id, _, _ in links}
        taught: dict[int, set[int]] = defaultdict(set)

        for lesson_id, subject_id in await self.lessons.list_disciplines_for_lessons(
            lesson_ids,
        ):
            taught[lesson_id].add(subject_id)

        minutes: dict[int, int] = defaultdict(int)
        covered: dict[int, set[int]] = defaultdict(set)

        for booking_id, lesson_id, start_time, end_time in links:
            minutes[booking_id] += minutes_between(start_time, end_time)
            covered[booking_id] |= taught.get(lesson_id, set())

        short = []
        uncovered = []
        missing = 0

        for booking_id, booking in bookings.items():
            if minutes[booking_id] != booking.duration:
                short.append(booking.presence.student_tax_code)
                continue

            requested = loaded_disciplines(booking) or set()

            if requested - covered[booking_id]:
                uncovered.append(booking.presence.student_tax_code)
                missing += len(requested - covered[booking_id])

        if not short and not uncovered:
            return

        people = await PersonRepository(self.session).get_options(short + uncovered)

        if short:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_by_count(_PARTIAL_COVERAGE_ERRORS, len(short)).format(
                    students=_joined(
                        [_person_label(people.get(code)) for code in set(short)],
                    ),
                ),
            )

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_by_count(_UNCOVERED_DISCIPLINES_ERRORS, missing).format(
                students=_joined(
                    [_person_label(people.get(code)) for code in set(uncovered)],
                ),
            ),
        )

    async def list_for(
        self,
        *,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[CalendarPublication]:
        return await self.repository.list(date_from=date_from, date_to=date_to)

    # Bookings closed and nobody booked: nothing will ever be published there.
    async def unbooked_bands(
        self,
        *,
        date_from: date,
        date_to: date,
    ) -> list[tuple[date, TimeBandEnum]]:
        date_to = min(date_to, date_from + timedelta(days=_MAX_UNBOOKED_DAYS))

        published = {
            (row.date, TimeBandEnum(row.band))
            for row in await self.repository.list(date_from=date_from, date_to=date_to)
        }
        booked = {
            (day, band_of(start))
            for day, start in await PresenceRepository(self.session).list_starts(
                date_from=date_from,
                date_to=date_to,
            )
        }

        now = self.now()
        settled: list[tuple[date, TimeBandEnum]] = []
        day = date_from

        while day <= date_to:
            for band in TimeBandEnum:
                if (
                    has_closed(day, band, now)
                    and (day, band) not in booked
                    and (day, band) not in published
                ):
                    settled.append((day, band))

            day += timedelta(days=1)

        return settled

    # Full snapshot of the band, so leaving the draft can restore it.
    async def picture_of(self, day: date, band: str) -> dict:
        lessons = await self.lessons.list_for_band(day, band)
        assignments = await self.assignments.list_for_day(day)
        supervisions = await self.supervisions.list_for_day(day)
        activities = await CalendarActivityRepository(self.session).list_for_band(
            day,
            band,
        )
        exclusions = await CalendarTeacherExclusionRepository(
            self.session,
        ).list_for_band(day, band)
        notes = await CalendarTeacherNoteRepository(self.session).list_for_band(
            day,
            band,
        )

        return snapshot_of(
            lessons,
            assignments,
            supervisions,
            activities,
            exclusions,
            notes,
        )

    # Unassigned activities become unreachable once the band is published.
    async def _assert_activities_assigned(self, day: date, band: str) -> None:
        waiting = await CalendarActivityRepository(
            self.session,
        ).find_unassigned_for_band(day, band)

        if not waiting:
            return

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_by_count(_UNASSIGNED_ACTIVITIES_ERRORS, len(waiting)).format(
                names=_joined([activity.name for activity in waiting]),
            ),
        )

    # Scoped to the band's lessons (days are published a band at a time) but the
    # day's supervision shifts. Checked only at publish: later edits could undo it.
    # A lesson cut by a room change counts as one without a room.
    async def _assert_rooms_settled(
        self,
        day: date,
        lessons: Sequence[Lesson],
    ) -> None:
        expected = teachers_in_building(lessons)

        if not expected:
            return

        assignments = await self.assignments.find_for_teachers(day, expected)
        adrift = teachers_adrift(lessons, assignments)

        if adrift:
            people = await PersonRepository(self.session).get_options(adrift)
            genders = {getattr(people.get(code), "gender", None) for code in adrift}
            errors = (
                _TEACHER_WITHOUT_A_ROOM_ERRORS
                if len(adrift) == 1
                else _TEACHERS_WITHOUT_A_ROOM_ERRORS
            )

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=errors[
                    GenderEnum.F if genders == {GenderEnum.F} else GenderEnum.M
                ].for_request().format(
                    teachers=_joined(
                        [_person_label(people.get(code)) for code in adrift],
                    ),
                ),
            )

        left_open = rooms_left_open(
            lessons,
            assignments,
            await self.supervisions.find_for_rooms(
                day,
                {row.room_id for row in assignments},
            ),
        )

        if not left_open:
            return

        rooms = await self.rooms.find_by_ids(sorted(left_open))

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_by_count(_ROOMS_LEFT_OPEN_ERRORS, len(left_open)).format(
                rooms=_joined([room.name for room in rooms]),
            ),
        )

    # Whether closing the draft would send the calendar out again.
    async def has_changes(self, publication: CalendarPublication) -> bool:
        stored = publication.draft_snapshot

        if stored is None:
            return False

        return differs(
            stored,
            await self.picture_of(publication.date, publication.band),
        )

    async def reopen(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> CalendarPublication:
        publication = await self._published_or_404(day, band)

        if publication.draft_snapshot is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_ALREADY_IN_DRAFT_ERROR.for_request(),
            )

        await assert_not_confirmed(self.session, day, band)
        await assert_band_claimed(self.session, identity, day, band)

        publication.draft_snapshot = await self.picture_of(day, band)
        publication.draft_opened_by = identity.tax_code

        async with integrity_guard(self.session, _PUBLISH_ERROR.for_request()):
            await self.repository.commit()
            await self.repository.refresh(publication)

        return publication

    async def settle(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> tuple[CalendarPublication, list[str], bool]:
        publication = await self._published_or_404(day, band)

        if publication.draft_snapshot is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_NOT_IN_DRAFT_ERROR.for_request(),
            )

        await assert_band_claimed(self.session, identity, day, band)

        lessons = await self.lessons.list_for_band(day, band)

        await self._assert_requests_covered(day, band, lessons)
        await self._assert_activities_assigned(day, band)
        await self._assert_rooms_settled(day, lessons)

        changed = await self.has_changes(publication)

        # After the comparison: realigned shifts alone send nothing out again.
        await realign_shifts(self.session, day, band, lessons)

        publication.draft_snapshot = None
        publication.draft_opened_by = None

        if changed:
            publication.published_at = func.now()
            publication.published_by = identity.tax_code

        warnings = await self._capacity_warnings(day, lessons)

        await self._let_go(identity, day, band)

        async with integrity_guard(self.session, _PUBLISH_ERROR.for_request()):
            await self.repository.commit()
            await self.repository.refresh(publication)

        return publication, warnings, changed

    # Only the opener may discard, since discarding undoes everything since the
    # draft opened. Drafts with no opener predate this check and are left alone.
    async def _assert_theirs_to_discard(
        self,
        publication: CalendarPublication,
        identity: IdentityContext,
    ) -> None:
        opener = publication.draft_opened_by

        if opener is None or opener == identity.tax_code:
            return

        people = await PersonRepository(self.session).get_options([opener])

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_NOT_YOURS_TO_DISCARD_ERROR.for_request().format(
                opener=_person_label(people.get(opener))
                or tr("un altro amministratore", "another administrator"),
            ),
        )

    async def _let_go(self, identity: IdentityContext, day: date, band: str) -> None:
        await CalendarBandLockRepository(self.session).release(
            day,
            band,
            identity.tax_code,
        )

    async def _published_or_404(self, day: date, band: str) -> CalendarPublication:
        publication = await self.repository.get_for_update(day, band)

        if publication is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR.for_request(),
            )

        return publication

    async def _capacity_warnings(
        self,
        day: date,
        lessons: Sequence[Lesson],
    ) -> list[str]:
        assignments = await self.assignments.find_for_teachers(
            day,
            teachers_in_building(lessons),
        )

        rooms = {
            room.id: room
            for room in await self.rooms.find_by_ids(
                [assignment.room_id for assignment in assignments],
            )
        }

        return capacity_warnings(lessons, assignments, rooms)

    async def publish(
        self,
        identity: IdentityContext,
        payload: CalendarPublicationCreate,
    ) -> tuple[CalendarPublication, list[str]]:
        band = str(payload.band)

        if await self.repository.is_published(payload.date, band):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_ALREADY_PUBLISHED_ERROR.for_request().format(
                    day=payload.date.strftime("%d/%m/%Y"),
                    band=time_band_label(band, request_language()).lower(),
                ),
            )

        assert_ready_to_publish(payload.date, payload.band, self.now())

        # Takes the band lock; also keeps two administrators from publishing at once.
        await assert_band_claimed(self.session, identity, payload.date, band)

        lessons = await self.lessons.list_for_band(payload.date, band)

        await self._assert_requests_covered(payload.date, band, lessons)
        await self._assert_activities_assigned(payload.date, band)
        await self._assert_rooms_settled(payload.date, lessons)
        await realign_shifts(self.session, payload.date, band, lessons)

        warnings = await self._capacity_warnings(payload.date, lessons)

        publication = CalendarPublication(
            date=payload.date,
            band=band,
            published_by=identity.tax_code,
        )

        await self._let_go(identity, payload.date, band)

        async with integrity_guard(self.session, _PUBLISH_ERROR.for_request()):
            await self.repository.create(publication)
            await self.repository.commit()
            await self.repository.refresh(publication)

        return publication, warnings

    # Restores the band to its snapshot; returns how many lessons could not come
    # back (availability withdrawn or request cancelled while the draft was open).
    async def discard(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> int:
        publication = await self._published_or_404(day, band)
        snapshot = publication.draft_snapshot

        if snapshot is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_NOT_IN_DRAFT_ERROR.for_request(),
            )

        await assert_band_claimed(self.session, identity, day, band)
        await self._assert_theirs_to_discard(publication, identity)

        # Back to how it went out, but never over what has begun since.
        begun = await started_rows(self.session, day, band)
        lost = await restore(self.session, day, band, snapshot)

        await self.session.flush()
        await assert_started_unchanged(self.session, day, band, begun)

        publication.draft_snapshot = None
        publication.draft_opened_by = None

        await self._let_go(identity, day, band)

        async with integrity_guard(self.session, _DISCARD_ERROR.for_request()):
            await self.repository.commit()
            await self.repository.refresh(publication)

        return lost

    async def unpublish(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> None:
        publication = await self._published_or_404(day, band)

        # Withdrawn, the band would leave the plan, and its hours the pay.
        await assert_not_confirmed(self.session, day, band)

        if await started_rows(self.session, day, band):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_STARTED_UNPUBLISH_ERROR.for_request(),
            )

        await assert_band_claimed(self.session, identity, day, band)

        await self.repository.delete(publication)
        await self._let_go(identity, day, band)
        await self.repository.commit()
