from collections.abc import Sequence
from datetime import date
from typing import Final

from fastapi import HTTPException, status

from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.teacher_room_assignment import (
    TeacherRoomAssignmentCreate,
    TeacherRoomAssignmentUpdate,
)
from app.services.lesson_guard import (
    assert_bands_not_published,
    find_bands_with_lessons,
    find_published_bands,
    published_band_error,
)
from app.services.room_occupancy import capacity_warnings, teachers_in_building

_ENTITY_LABEL: Final[str] = "l'assegnazione"
_NOT_FOUND_ERROR: Final[str] = "Assegnazione non trovata"
_ROOM_NOT_FOUND_ERROR: Final[str] = "Stanza non trovata"
_CREATE_ERROR: Final[str] = "Errore durante l'assegnazione della stanza."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_NOT_CONVENED_ERROR: Final[str] = (
    "Il docente non ha lezioni in sede in questa giornata: non gli va "
    "assegnata una stanza."
)

_ALREADY_ASSIGNED_ERROR: Final[str] = (
    "Il docente ha già una stanza assegnata in questa giornata."
)


class TeacherRoomAssignmentService:
    def __init__(
        self,
        repository: TeacherRoomAssignmentRepository,
        lessons: LessonRepository,
        rooms: RoomRepository,
    ) -> None:
        self.repository = repository
        self.lessons = lessons
        self.rooms = rooms

    @property
    def session(self):  # noqa: ANN201 - mirrors the other services
        return self.repository.session

    # A room is handed out once the lessons are settled, so the teacher has to
    # already have some, and to be in the building for at least one of them.
    async def _assert_convened(self, day: date, teacher_tax_code: str) -> None:
        lessons = await self.lessons.list_for_day(day)

        if teacher_tax_code not in teachers_in_building(lessons):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_CONVENED_ERROR,
            )

    # Every band of the day this teacher actually teaches in: those are the ones
    # that have to still be open for their room to move.
    async def _assert_day_open_for(
        self,
        day: date,
        teacher_tax_code: str,
    ) -> None:
        lessons = await self.lessons.list_for_day(day)
        bands = {
            lesson.band
            for lesson in lessons
            if lesson.availability.teacher_tax_code == teacher_tax_code
        }

        await assert_bands_not_published(self.session, [(day, band) for band in bands])

    async def _warnings_for(self, day: date) -> list[str]:
        lessons = await self.lessons.list_for_day(day)
        assignments = await self.repository.list_for_day(day)
        rooms = {
            room.id: room
            for room in await self.rooms.find_by_ids(
                [assignment.room_id for assignment in assignments],
            )
        }

        return capacity_warnings(lessons, assignments, rooms)

    async def list_for_day(self, day: date) -> Sequence[TeacherRoomAssignment]:
        return await self.repository.list_for_day(day)

    async def get_or_404(
        self,
        day: date,
        teacher_tax_code: str,
    ) -> TeacherRoomAssignment:
        assignment = await self.repository.get(day, teacher_tax_code)

        if assignment is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return assignment

    async def _room_or_404(self, room_id: int) -> None:
        if await self.rooms.get_by_id(room_id) is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_ROOM_NOT_FOUND_ERROR,
            )

    async def assign(
        self,
        payload: TeacherRoomAssignmentCreate,
    ) -> tuple[TeacherRoomAssignment, list[str]]:
        existing = await self.repository.get(payload.date, payload.teacher_tax_code)

        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_ALREADY_ASSIGNED_ERROR,
            )

        await self._assert_day_open_for(payload.date, payload.teacher_tax_code)
        await self._assert_convened(payload.date, payload.teacher_tax_code)
        await self._room_or_404(payload.room_id)

        assignment = TeacherRoomAssignment(
            date=payload.date,
            teacher_tax_code=payload.teacher_tax_code,
            room_id=payload.room_id,
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(assignment)
            await self.repository.commit()

        return (
            await self.get_or_404(payload.date, payload.teacher_tax_code),
            await self._warnings_for(payload.date),
        )

    async def update(
        self,
        day: date,
        teacher_tax_code: str,
        payload: TeacherRoomAssignmentUpdate,
    ) -> tuple[TeacherRoomAssignment, list[str]]:
        assignment = await self.get_or_404(day, teacher_tax_code)

        assert_not_stale(
            assignment,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        await self._assert_day_open_for(day, teacher_tax_code)
        await self._room_or_404(payload.room_id)

        # The shifts follow the teacher to the new room, through the composite
        # key's ON UPDATE CASCADE. Whether the room they left is still watched
        # over is answered when the band is published.
        assignment.room_id = payload.room_id

        async with integrity_guard(self.session, _UPDATE_ERROR):
            await self.repository.commit()

        return (
            await self.get_or_404(day, teacher_tax_code),
            await self._warnings_for(day),
        )

    # Removing the assignment takes the teacher's shifts with it, by cascade.
    # The count goes back to the caller so it can be said out loud rather than
    # discovered afterwards.
    async def unassign(self, day: date, teacher_tax_code: str) -> int:
        assignment = await self.get_or_404(day, teacher_tax_code)

        published = await find_published_bands(self.session, day)
        with_lessons = await find_bands_with_lessons(self.session, day)
        clashing = sorted(published & with_lessons)

        if clashing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=published_band_error(day, clashing[0]),
            )

        shifts = await self.repository.count_supervisions(day, teacher_tax_code)

        await self.repository.delete(assignment)
        await self.repository.commit()

        return shifts
