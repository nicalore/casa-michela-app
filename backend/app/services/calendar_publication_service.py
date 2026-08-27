from collections import defaultdict
from collections.abc import Callable, Sequence
from datetime import date, datetime
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import func

from app.api.rbac import IdentityContext
from app.core.booking_close import assert_ready_to_publish, now_in_rome
from app.core.integrity import integrity_guard
from app.core.labels import time_band_label
from app.core.time_band import TimeBandEnum, band_bounds
from app.core.time_step import minutes_between
from app.models.booking_disciplines import loaded_disciplines
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
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
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import CalendarPublicationCreate
from app.services.calendar_snapshot import differs, restore, snapshot_of
from app.services.lesson_guard import assert_band_claimed
from app.services.room_occupancy import (
    capacity_warnings,
    rooms_left_open,
    teachers_in_building,
)

_NOT_FOUND_ERROR: Final[str] = "Questo calendario non è pubblicato."
_NOT_IN_DRAFT_ERROR: Final[str] = "Questo calendario non è in bozza."
_ALREADY_IN_DRAFT_ERROR: Final[str] = "Questo calendario è già in bozza."
_PUBLISH_ERROR: Final[str] = "Errore durante la pubblicazione."
_DISCARD_ERROR: Final[str] = "Errore durante l'uscita dalla bozza."

_ALREADY_PUBLISHED_ERROR: Final[str] = (
    "Il calendario del {day} ({band}) è già pubblicato."
)

_PARTIAL_COVERAGE_ERROR: Final[str] = (
    "Alcune prenotazioni sono coperte solo in parte: {students}. Completa o "
    "rimuovi le lezioni prima di pubblicare."
)

_UNCOVERED_DISCIPLINES_ERROR: Final[str] = (
    "Alcune discipline richieste non sono assegnate a nessuna lezione: "
    "{students}."
)

_UNPLANNED_ERROR: Final[str] = (
    "Alcune prenotazioni non sono state pianificate: {students}. Mettile in "
    "calendario o annullale prima di pubblicare."
)

_UNASSIGNED_ACTIVITIES_ERROR: Final[str] = (
    "Alcune attività non sono state assegnate a nessun docente: {names}. "
    "Assegnale o eliminale prima di pubblicare."
)

_TEACHERS_WITHOUT_A_ROOM_ERROR: Final[str] = (
    "Alcuni docenti in presenza non hanno una stanza assegnata: {teachers}."
)

_ROOMS_LEFT_OPEN_ERROR: Final[str] = (
    "Alcune stanze non hanno un responsabile per tutte le ore di lezione: "
    "{rooms}."
)

_NOT_YOURS_TO_DISCARD_ERROR: Final[str] = (
    "La bozza è stata aperta da {opener}: uscendone si annullerebbe anche il "
    "suo lavoro. Puoi pubblicarla, oppure chiedere a {opener} di uscirne."
)

_MAX_NAMED: Final[int] = 5


def _person_label(person: object) -> str:
    first = getattr(person, "first_name", "") or ""
    last = getattr(person, "last_name", "") or ""

    return f"{first} {last}".strip()


def _joined(names: Sequence[str]) -> str:
    shown = sorted(names)[:_MAX_NAMED]
    rest = len(names) - len(shown)

    return ", ".join(shown) + (f" e altri {rest}" if rest > 0 else "")


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
            detail=_UNPLANNED_ERROR.format(
                students=_joined(
                    [_person_label(people.get(code)) for code in left_out],
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

        for booking_id, booking in bookings.items():
            if minutes[booking_id] != booking.duration:
                short.append(booking.presence.student_tax_code)
                continue

            requested = loaded_disciplines(booking) or set()

            if requested - covered[booking_id]:
                uncovered.append(booking.presence.student_tax_code)

        if not short and not uncovered:
            return

        people = await PersonRepository(self.session).get_options(short + uncovered)

        if short:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_PARTIAL_COVERAGE_ERROR.format(
                    students=_joined(
                        [_person_label(people.get(code)) for code in short],
                    ),
                ),
            )

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UNCOVERED_DISCIPLINES_ERROR.format(
                students=_joined(
                    [_person_label(people.get(code)) for code in uncovered],
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

        return snapshot_of(
            lessons,
            assignments,
            supervisions,
            activities,
            exclusions,
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
            detail=_UNASSIGNED_ACTIVITIES_ERROR.format(
                names=_joined([activity.name for activity in waiting]),
            ),
        )

    # Scoped to the band's lessons (days are published a band at a time) but the
    # day's supervision shifts. Checked only at publish: later edits could undo it.
    async def _assert_rooms_settled(
        self,
        day: date,
        lessons: Sequence[Lesson],
    ) -> None:
        expected = teachers_in_building(lessons)

        if not expected:
            return

        assignments = await self.assignments.find_for_teachers(day, expected)
        adrift = expected - {row.teacher_tax_code for row in assignments}

        if adrift:
            people = await PersonRepository(self.session).get_options(adrift)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_TEACHERS_WITHOUT_A_ROOM_ERROR.format(
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
            detail=_ROOMS_LEFT_OPEN_ERROR.format(
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
                detail=_ALREADY_IN_DRAFT_ERROR,
            )

        await assert_band_claimed(self.session, identity, day, band)

        publication.draft_snapshot = await self.picture_of(day, band)
        publication.draft_opened_by = identity.tax_code

        async with integrity_guard(self.session, _PUBLISH_ERROR):
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
                detail=_NOT_IN_DRAFT_ERROR,
            )

        await assert_band_claimed(self.session, identity, day, band)

        lessons = await self.lessons.list_for_band(day, band)

        await self._assert_requests_covered(day, band, lessons)
        await self._assert_activities_assigned(day, band)
        await self._assert_rooms_settled(day, lessons)

        changed = await self.has_changes(publication)

        publication.draft_snapshot = None
        publication.draft_opened_by = None

        if changed:
            publication.published_at = func.now()
            publication.published_by = identity.tax_code

        warnings = await self._capacity_warnings(day, lessons)

        await self._let_go(identity, day, band)

        async with integrity_guard(self.session, _PUBLISH_ERROR):
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
            detail=_NOT_YOURS_TO_DISCARD_ERROR.format(
                opener=_person_label(people.get(opener)) or "un altro amministratore",
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
                detail=_NOT_FOUND_ERROR,
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
                detail=_ALREADY_PUBLISHED_ERROR.format(
                    day=payload.date.strftime("%d/%m/%Y"),
                    band=time_band_label(band).lower(),
                ),
            )

        assert_ready_to_publish(payload.date, payload.band, self.now())

        # Takes the band lock; also keeps two administrators from publishing at once.
        await assert_band_claimed(self.session, identity, payload.date, band)

        lessons = await self.lessons.list_for_band(payload.date, band)

        await self._assert_requests_covered(payload.date, band, lessons)
        await self._assert_activities_assigned(payload.date, band)
        await self._assert_rooms_settled(payload.date, lessons)

        warnings = await self._capacity_warnings(payload.date, lessons)

        publication = CalendarPublication(
            date=payload.date,
            band=band,
            published_by=identity.tax_code,
        )

        await self._let_go(identity, payload.date, band)

        async with integrity_guard(self.session, _PUBLISH_ERROR):
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
                detail=_NOT_IN_DRAFT_ERROR,
            )

        await assert_band_claimed(self.session, identity, day, band)
        await self._assert_theirs_to_discard(publication, identity)

        lost = await restore(self.session, day, band, snapshot)

        publication.draft_snapshot = None
        publication.draft_opened_by = None

        await self._let_go(identity, day, band)

        async with integrity_guard(self.session, _DISCARD_ERROR):
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

        await assert_band_claimed(self.session, identity, day, band)

        await self.repository.delete(publication)
        await self._let_go(identity, day, band)
        await self.repository.commit()
