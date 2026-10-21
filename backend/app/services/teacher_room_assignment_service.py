from collections.abc import Sequence
from datetime import date, time
from typing import Final, NamedTuple

from fastapi import HTTPException, status

from app.api.rbac import IdentityContext
from app.core.booking_close import bands_of
from app.core.integrity import integrity_guard
from app.models.lesson import Lesson
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import MIDNIGHT, TeacherRoomAssignment
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.teacher_room_assignment import (
    RoomPlanShift,
    RoomPlanUpdate,
    RoomStretch,
    TeacherRoomAssignmentCreate,
)
from app.services.lesson_guard import (
    assert_bands_claimed,
    assert_bands_editable,
    find_bands_with_lessons,
    find_settled_bands,
    published_band_error,
)
from app.services.room_occupancy import (
    capacity_warnings,
    stretch_at,
    stretch_index,
    teacher_of,
    teachers_in_building,
)
from app.services.room_supervision_service import (
    NOT_ASSIGNED_ERROR,
    OVERLAPPING_SHIFT_ERROR,
    assert_within_presence,
)

_NOT_FOUND_ERROR: Final[str] = "Assegnazione non trovata"
_ROOM_NOT_FOUND_ERROR: Final[str] = "Stanza non trovata"
_CREATE_ERROR: Final[str] = "Errore durante l'assegnazione della stanza."
_PLAN_ERROR: Final[str] = "Errore durante il salvataggio delle stanze."

_NOT_CONVENED_ERROR: Final[str] = (
    "Il docente non ha lezioni in sede in questa giornata: non gli va "
    "assegnata una stanza."
)

_ALREADY_ASSIGNED_ERROR: Final[str] = (
    "Il docente ha già una stanza assegnata in questa giornata."
)


class _Stretch(NamedTuple):
    start_time: time
    room_id: int


# Sorted, one row per start, same-room neighbours joined, the first from midnight.
def _normalized(stretches: Sequence[RoomStretch]) -> list[_Stretch]:
    by_start = {stretch.start_time: stretch.room_id for stretch in stretches}
    rows: list[_Stretch] = []

    for start in sorted(by_start):
        room_id = by_start[start]

        if rows and rows[-1].room_id == room_id:
            continue

        rows.append(_Stretch(MIDNIGHT if not rows else start, room_id))

    return rows


def _same(
    stored: Sequence[TeacherRoomAssignment],
    wanted: Sequence[_Stretch],
) -> bool:
    return [(row.start_time, row.room_id) for row in stored] == list(wanted)


def _wanted_at(
    stretches: Sequence[_Stretch],
    start_time: time,
    end_time: time,
) -> _Stretch | None:
    index = stretch_index(
        [stretch.start_time for stretch in stretches],
        start_time,
        end_time,
    )

    return stretches[index] if index is not None else None


def _rooms_differ(
    stored: Sequence[TeacherRoomAssignment],
    wanted: Sequence[_Stretch],
    lesson: Lesson,
) -> bool:
    before = stretch_at(stored, lesson.start_time, lesson.end_time)
    after = _wanted_at(wanted, lesson.start_time, lesson.end_time)

    return (before.room_id if before else None) != (after.room_id if after else None)


def _shift_key(
    shift: RoomSupervision | RoomPlanShift,
) -> tuple[str, int, time, time]:
    return (shift.teacher_tax_code, shift.room_id, shift.start_time, shift.end_time)


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

    async def _assert_convened(self, day: date, teacher_tax_code: str) -> None:
        lessons = await self.lessons.list_for_day(day)

        if teacher_tax_code not in teachers_in_building(lessons):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_CONVENED_ERROR,
            )

    # The teacher's rows span the day, so they belong to every band they teach in.
    # Locks too: two band builders sharing a teacher cannot move the room apart.
    async def _bands_of(self, day: date, teacher_tax_code: str) -> set[str]:
        lessons = await self.lessons.list_for_day(day)

        return {
            lesson.band
            for lesson in lessons
            if lesson.availability.teacher_tax_code == teacher_tax_code
        }

    async def _assert_day_open_for(
        self,
        identity: IdentityContext,
        day: date,
        teacher_tax_code: str,
    ) -> None:
        pairs = [(day, band) for band in await self._bands_of(day, teacher_tax_code)]

        await assert_bands_editable(self.session, pairs)
        await assert_bands_claimed(self.session, identity, pairs)

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

    async def _rows_or_404(
        self,
        day: date,
        teacher_tax_code: str,
    ) -> Sequence[TeacherRoomAssignment]:
        rows = await self.repository.list_for_teacher(day, teacher_tax_code)

        if not rows:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return rows

    async def _rooms_or_404(self, room_ids: set[int]) -> None:
        if len(await self.rooms.find_by_ids(sorted(room_ids))) != len(room_ids):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_ROOM_NOT_FOUND_ERROR,
            )

    async def assign(
        self,
        identity: IdentityContext,
        payload: TeacherRoomAssignmentCreate,
    ) -> tuple[TeacherRoomAssignment, list[str]]:
        if await self.repository.list_for_teacher(
            payload.date,
            payload.teacher_tax_code,
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_ALREADY_ASSIGNED_ERROR,
            )

        await self._assert_day_open_for(
            identity,
            payload.date,
            payload.teacher_tax_code,
        )
        await self._assert_convened(payload.date, payload.teacher_tax_code)
        await self._rooms_or_404({payload.room_id})

        assignment = TeacherRoomAssignment(
            date=payload.date,
            teacher_tax_code=payload.teacher_tax_code,
            start_time=MIDNIGHT,
            room_id=payload.room_id,
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(assignment)
            await self.repository.commit()

        rows = await self._rows_or_404(payload.date, payload.teacher_tax_code)

        return rows[0], await self._warnings_for(payload.date)

    # Every room of the teacher's day goes, and their shifts with them.
    async def unassign(
        self,
        identity: IdentityContext,
        day: date,
        teacher_tax_code: str,
    ) -> int:
        rows = await self._rows_or_404(day, teacher_tax_code)

        settled = await find_settled_bands(self.session, day)
        with_lessons = await find_bands_with_lessons(self.session, day)
        clashing = sorted(settled & with_lessons)

        if clashing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=published_band_error(day, clashing[0]),
            )

        await assert_bands_claimed(
            self.session,
            identity,
            [(day, band) for band in await self._bands_of(day, teacher_tax_code)],
        )

        shifts = await self.repository.count_supervisions(day, teacher_tax_code)

        for row in rows:
            await self.repository.delete(row)

        await self.repository.commit()

        return shifts

    def _shift_starts(
        self,
        wanted: dict[str, list[_Stretch]],
        shifts: Sequence[RoomPlanShift],
    ) -> list[time]:
        starts = []

        for shift in shifts:
            stretch = _wanted_at(
                wanted.get(shift.teacher_tax_code, []),
                shift.start_time,
                shift.end_time,
            )

            if stretch is None or stretch.room_id != shift.room_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=NOT_ASSIGNED_ERROR,
                )

            starts.append(stretch.start_time)

        by_teacher: dict[str, list[RoomPlanShift]] = {}

        for shift in shifts:
            by_teacher.setdefault(shift.teacher_tax_code, []).append(shift)

        # Day-wide: nobody supervises two rooms at once.
        for own in by_teacher.values():
            own.sort(key=lambda shift: shift.start_time)

            for before, after in zip(own, own[1:], strict=False):
                if after.start_time < before.end_time:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=OVERLAPPING_SHIFT_ERROR,
                    )

        return starts

    # Bands whose lessons change room, and bands a changed shift touches.
    def _touched_bands(
        self,
        lessons: Sequence[Lesson],
        stored: dict[str, list[TeacherRoomAssignment]],
        wanted: dict[str, list[_Stretch]],
        stored_shifts: Sequence[RoomSupervision],
        shifts: Sequence[RoomPlanShift],
    ) -> tuple[set[str], set[str]]:
        moved = {
            lesson.band
            for lesson in lessons
            if teacher_of(lesson) in wanted
            and lesson.teacher_mode == "presence"
            and _rooms_differ(
                stored.get(teacher_of(lesson), []),
                wanted[teacher_of(lesson)],
                lesson,
            )
        }

        before = {_shift_key(shift) for shift in stored_shifts}
        after = {_shift_key(shift) for shift in shifts}

        watched = {
            str(band)
            for _, _, start, end in before ^ after
            for band in bands_of(start, end)
        }

        return moved, watched

    # The wizard's save: the listed teachers' rooms and shifts, all or nothing.
    async def replace_day(
        self,
        identity: IdentityContext,
        day: date,
        payload: RoomPlanUpdate,
    ) -> tuple[
        Sequence[TeacherRoomAssignment],
        Sequence[RoomSupervision],
        list[str],
    ]:
        lessons = await self.lessons.list_for_day(day)
        in_building = teachers_in_building(lessons)

        wanted = {
            teacher.teacher_tax_code: _normalized(teacher.stretches)
            for teacher in payload.teachers
        }

        if any(rows and code not in in_building for code, rows in wanted.items()):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_CONVENED_ERROR,
            )

        await self._rooms_or_404(
            {row.room_id for rows in wanted.values() for row in rows}
            | {shift.room_id for shift in payload.supervisions},
        )

        starts = self._shift_starts(wanted, payload.supervisions)

        for shift in payload.supervisions:
            await assert_within_presence(
                self.session,
                day,
                shift.teacher_tax_code,
                shift.start_time,
                shift.end_time,
            )

        stored: dict[str, list[TeacherRoomAssignment]] = {}

        for row in await self.repository.list_for_day(day):
            if row.teacher_tax_code in wanted:
                stored.setdefault(row.teacher_tax_code, []).append(row)

        shifts = RoomSupervisionRepository(self.session)
        stored_shifts = [
            shift
            for shift in await shifts.list_for_day(day)
            if shift.teacher_tax_code in wanted
        ]

        moved, watched = self._touched_bands(
            lessons,
            stored,
            wanted,
            stored_shifts,
            payload.supervisions,
        )

        await assert_bands_editable(self.session, [(day, band) for band in moved])
        await assert_bands_claimed(
            self.session,
            identity,
            [(day, band) for band in sorted(moved | watched)],
        )

        async with integrity_guard(self.session, _PLAN_ERROR):
            for shift in stored_shifts:
                await self.session.delete(shift)

            # Before the rows: their cascade would otherwise take these first.
            await self.session.flush()

            for code, rows in wanted.items():
                if _same(stored.get(code, []), rows):
                    continue

                for row in stored.get(code, []):
                    await self.session.delete(row)

                await self.session.flush()

                for row in rows:
                    self.session.add(
                        TeacherRoomAssignment(
                            date=day,
                            teacher_tax_code=code,
                            start_time=row.start_time,
                            room_id=row.room_id,
                        ),
                    )

            await self.session.flush()

            for shift, start in zip(payload.supervisions, starts, strict=True):
                self.session.add(
                    RoomSupervision(
                        date=day,
                        teacher_tax_code=shift.teacher_tax_code,
                        room_id=shift.room_id,
                        assignment_start=start,
                        start_time=shift.start_time,
                        end_time=shift.end_time,
                    ),
                )

            await self.repository.commit()

        return (
            await self.repository.list_for_day(day),
            await shifts.list_for_day(day),
            await self._warnings_for(day),
        )
