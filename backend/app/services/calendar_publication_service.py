from collections import defaultdict
from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.core.labels import time_band_label
from app.core.time_step import minutes_between
from app.models.booking_disciplines import loaded_disciplines
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import CalendarPublicationCreate
from app.services.room_occupancy import (
    capacity_warnings,
    coverage_gap,
    lessons_by_room,
    teachers_in_building,
)

_NOT_FOUND_ERROR: Final[str] = "Questa fascia non è pubblicata."
_PUBLISH_ERROR: Final[str] = "Errore durante la pubblicazione."

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

_TEACHER_WITHOUT_ROOM_ERROR: Final[str] = (
    "Questi docenti sono in sede ma non hanno una stanza assegnata: {teachers}."
)

_UNWATCHED_ROOM_ERROR: Final[str] = (
    "La stanza {room} non è presidiata dalle {start} alle {end}."
)

# How many names to put in a message before it stops being a message.
_MAX_NAMED: Final[int] = 5


def _format_time(value: time) -> str:
    return value.strftime("%H:%M")


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
    ) -> None:
        self.repository = repository
        self.lessons = lessons
        self.assignments = assignments
        self.supervisions = supervisions
        self.rooms = rooms

    @property
    def session(self):  # noqa: ANN201 - mirrors the other services
        return self.repository.session

    # Every request touched by this band has to be either wholly taught or not
    # taught at all: half a request is a state of the work, not a result. Since
    # the parts of a request all fall in one band, the whole check is local to
    # the band being published.
    #
    # The disciplines of the parts have to cover what was asked for. They may
    # overlap — two teachers taking turns on one discipline is a real
    # arrangement — so it is the union that has to match, not a partition.
    async def _assert_requests_covered(self, lessons: Sequence[Lesson]) -> None:
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

    # From the teachers convened, never from the catalogue of rooms: a day with
    # little work leaves most rooms shut, and a room nobody is in asks for
    # nothing.
    async def _assert_rooms_assigned(
        self,
        day: date,
        lessons: Sequence[Lesson],
    ) -> Sequence[TeacherRoomAssignment]:
        in_building = teachers_in_building(lessons)
        assignments = await self.assignments.find_for_teachers(day, in_building)
        assigned = {assignment.teacher_tax_code for assignment in assignments}
        missing = sorted(in_building - assigned)

        if missing:
            people = await PersonRepository(self.session).get_options(missing)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_TEACHER_WITHOUT_ROOM_ERROR.format(
                    teachers=_joined(
                        [_person_label(people.get(code)) for code in missing],
                    ),
                ),
            )

        return assignments

    async def _assert_rooms_watched(
        self,
        day: date,
        lessons: Sequence[Lesson],
        assignments: Sequence[TeacherRoomAssignment],
    ) -> None:
        grouped = lessons_by_room(lessons, assignments)

        if not grouped:
            return

        shifts = await self.supervisions.find_for_rooms(day, list(grouped))
        by_room: dict[int, list[RoomSupervision]] = defaultdict(list)

        for shift in shifts:
            by_room[shift.room_id].append(shift)

        rooms = {
            room.id: room for room in await self.rooms.find_by_ids(list(grouped))
        }

        for room_id, room_lessons in grouped.items():
            gap = coverage_gap(room_lessons, by_room.get(room_id, []))

            if gap is not None:
                room = rooms.get(room_id)

                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_UNWATCHED_ROOM_ERROR.format(
                        room=room.name if room is not None else room_id,
                        start=_format_time(gap[0]),
                        end=_format_time(gap[1]),
                    ),
                )

    async def list_for(
        self,
        *,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[CalendarPublication]:
        return await self.repository.list(date_from=date_from, date_to=date_to)

    async def publish(
        self,
        identity: IdentityContext,
        payload: CalendarPublicationCreate,
    ) -> tuple[CalendarPublication, list[str]]:
        band = str(payload.band)

        # Explicit rather than idempotent, so a client learns that somebody else
        # published in the meantime instead of silently agreeing.
        if await self.repository.is_published(payload.date, band):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_ALREADY_PUBLISHED_ERROR.format(
                    day=payload.date.strftime("%d/%m/%Y"),
                    band=time_band_label(band).lower(),
                ),
            )

        lessons = await self.lessons.list_for_band(payload.date, band)

        await self._assert_requests_covered(lessons)
        assignments = await self._assert_rooms_assigned(payload.date, lessons)
        await self._assert_rooms_watched(payload.date, lessons, assignments)

        rooms = {
            room.id: room
            for room in await self.rooms.find_by_ids(
                [assignment.room_id for assignment in assignments],
            )
        }
        # Over capacity is worth saying and not worth refusing: the number is
        # optional, and nobody should be blocked by a count never taken.
        warnings = capacity_warnings(lessons, assignments, rooms)

        publication = CalendarPublication(
            date=payload.date,
            band=band,
            published_by=identity.tax_code,
        )

        async with integrity_guard(self.session, _PUBLISH_ERROR):
            await self.repository.create(publication)
            await self.repository.commit()
            await self.repository.refresh(publication)

        return publication, warnings

    # No precondition at all: unpublishing is always allowed, and is the way out
    # of every block the publication puts in place.
    async def unpublish(self, day: date, band: str) -> None:
        publication = await self.repository.get(day, band)

        if publication is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        await self.repository.delete(publication)
        await self.repository.commit()
