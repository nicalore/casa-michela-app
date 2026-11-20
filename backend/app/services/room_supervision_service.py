from collections import defaultdict
from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.booking_close import bands_of
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.core.time_band import band_of
from app.models.availability import Availability
from app.models.lesson import Lesson
from app.models.person import GenderEnum
from app.models.room_supervision import RoomSupervision
from app.repositories.person_repository import PersonRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.room_supervision import (
    RoomSupervisionCreate,
    RoomSupervisionUpdate,
)
from app.services.bilingual import Bilingual
from app.services.calendar_freeze import (
    assert_not_confirmed,
    assert_not_started,
    has_begun,
)
from app.services.lesson_guard import assert_bands_claimed
from app.services.room_occupancy import StayKey, stretch_at, watched_stays

_ENTITY_LABEL: Final[Bilingual] = Bilingual(
    "il turno",
    "the shift",
)
_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Turno da responsabile non trovato",
    "Supervisor shift not found",
)
_CREATE_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Il docente non ha questa stanza assegnata in questa giornata.",
        "The teacher does not have this room assigned on this day.",
    ),
    GenderEnum.F: Bilingual(
        "La docente non ha questa stanza assegnata in questa giornata.",
        "The teacher does not have this room assigned on this day.",
    ),
}
_UPDATE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante l'aggiornamento.",
    "Something went wrong while saving.",
)

NOT_ASSIGNED_ERROR: Final[Bilingual] = Bilingual(
    "Solo un docente assegnato a questa stanza può esserne responsabile.",
    "Only a teacher assigned to this room can supervise it.",
)

_OUTSIDE_AVAILABILITY_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Il turno deve rientrare nelle disponibilità in presenza del docente in "
        "questa giornata.",
        "The shift must fall within the teacher's in-person availability on this day.",
    ),
    GenderEnum.F: Bilingual(
        "Il turno deve rientrare nelle disponibilità in presenza della docente in "
        "questa giornata.",
        "The shift must fall within the teacher's in-person availability on this day.",
    ),
}

OVERLAPPING_SHIFT_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Il docente ha già un turno da responsabile sovrapposto a quest'orario.",
        "The teacher already has a supervisor shift overlapping this time.",
    ),
    GenderEnum.F: Bilingual(
        "La docente ha già un turno da responsabile sovrapposto a quest'orario.",
        "The teacher already has a supervisor shift overlapping this time.",
    ),
}


# The shift must fall inside the union of the teacher's in-person stretches.
async def assert_within_presence(
    session: AsyncSession,
    day: date,
    teacher_tax_code: str,
    start_time: time,
    end_time: time,
) -> None:
    stretches = (
        await session.execute(
            select(Availability.start_time, Availability.end_time)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                Availability.date == day,
                Availability.mode == "presence",
            )
            .order_by(Availability.start_time),
        )
    ).all()

    reached = start_time

    for stretch_start, stretch_end in stretches:
        if stretch_start > reached:
            break

        reached = max(reached, stretch_end)

        if reached >= end_time:
            return

    gender = await PersonRepository(session).gender(teacher_tax_code)

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=_OUTSIDE_AVAILABILITY_ERRORS[gender].for_request(),
    )


# Shifts follow the band's lessons as they are now, as the wizard writes them:
# moved lessons would otherwise leave the old hours on convocations and pay.
# A group with a begun shift keeps its hours.
async def realign_shifts(
    session: AsyncSession,
    day: date,
    band: str,
    lessons: Sequence[Lesson],
) -> None:
    assignments = await TeacherRoomAssignmentRepository(session).list_for_day(day)
    shifts = await RoomSupervisionRepository(session).list_for_day(day)

    watching = {(shift.room_id, shift.teacher_tax_code) for shift in shifts}
    wanted = {
        key: spans
        for key, spans in watched_stays(lessons, assignments, watching).items()
        if key[3] == band
    }

    held: dict[StayKey, list[RoomSupervision]] = defaultdict(list)

    for shift in shifts:
        if str(band_of(shift.start_time)) == band:
            key = (
                shift.room_id,
                shift.teacher_tax_code,
                shift.assignment_start,
                band,
            )
            held[key].append(shift)

    for key in held.keys() | wanted.keys():
        rows = sorted(held.get(key, []), key=lambda row: row.start_time)
        spans = wanted.get(key, [])

        if [(row.start_time, row.end_time) for row in rows] == spans:
            continue

        if any(has_begun(day, row.start_time) for row in rows):
            continue

        for row in rows:
            await session.delete(row)

        # Before the new rows: same slot, same unique key.
        await session.flush()

        room_id, teacher_tax_code, assignment_start, _ = key

        for start_time, end_time in spans:
            session.add(
                RoomSupervision(
                    date=day,
                    teacher_tax_code=teacher_tax_code,
                    room_id=room_id,
                    assignment_start=assignment_start,
                    start_time=start_time,
                    end_time=end_time,
                ),
            )

    await session.flush()


class RoomSupervisionService:
    def __init__(
        self,
        repository: RoomSupervisionRepository,
        assignments: TeacherRoomAssignmentRepository,
    ) -> None:
        self.repository = repository
        self.assignments = assignments

    @property
    def session(self):  # noqa: ANN201 - mirrors the other services
        return self.repository.session

    # Every band the stretch touches, not just the one it starts in.
    async def _assert_claimed(
        self,
        identity: IdentityContext,
        day: date,
        start_time: time,
        end_time: time,
    ) -> None:
        for band in bands_of(start_time, end_time):
            await assert_not_confirmed(self.session, day, str(band))

        assert_not_started(day, start_time)

        await assert_bands_claimed(
            self.session,
            identity,
            [(day, band) for band in bands_of(start_time, end_time)],
        )

    # The composite FK already enforces this; checked for a readable message.
    async def _assignment_start(
        self,
        day: date,
        teacher_tax_code: str,
        room_id: int,
        start_time: time,
        end_time: time,
    ) -> time:
        stretch = stretch_at(
            await self.assignments.list_for_teacher(day, teacher_tax_code),
            start_time,
            end_time,
        )

        if stretch is None or stretch.room_id != room_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=NOT_ASSIGNED_ERROR.for_request(),
            )

        return stretch.start_time

    async def _assert_within_availability(
        self,
        day: date,
        teacher_tax_code: str,
        start_time: time,
        end_time: time,
    ) -> None:
        await assert_within_presence(
            self.session,
            day,
            teacher_tax_code,
            start_time,
            end_time,
        )

    # Day-wide: nobody supervises two rooms at once.
    async def _assert_no_overlap(
        self,
        day: date,
        teacher_tax_code: str,
        start_time: time,
        end_time: time,
        *,
        exclude_id: int | None,
    ) -> None:
        clash = await self.repository.find_teacher_overlap(
            day=day,
            teacher_tax_code=teacher_tax_code,
            start_time=start_time,
            end_time=end_time,
            exclude_id=exclude_id,
        )

        if clash is not None:
            gender = await PersonRepository(self.session).gender(teacher_tax_code)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=OVERLAPPING_SHIFT_ERRORS[gender].for_request(),
            )

    async def list_for_day(
        self,
        day: date,
        *,
        room_id: int | None,
    ) -> Sequence[RoomSupervision]:
        return await self.repository.list_for_day(day, room_id=room_id)

    async def get_or_404(self, supervision_id: int) -> RoomSupervision:
        supervision = await self.repository.get_by_id(supervision_id)

        if supervision is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR.for_request(),
            )

        return supervision

    async def create(
        self,
        identity: IdentityContext,
        payload: RoomSupervisionCreate,
    ) -> RoomSupervision:
        await self._assert_claimed(
            identity,
            payload.date,
            payload.start_time,
            payload.end_time,
        )
        assignment_start = await self._assignment_start(
            payload.date,
            payload.teacher_tax_code,
            payload.room_id,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_within_availability(
            payload.date,
            payload.teacher_tax_code,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            payload.date,
            payload.teacher_tax_code,
            payload.start_time,
            payload.end_time,
            exclude_id=None,
        )

        supervision = RoomSupervision(
            date=payload.date,
            teacher_tax_code=payload.teacher_tax_code,
            room_id=payload.room_id,
            assignment_start=assignment_start,
            start_time=payload.start_time,
            end_time=payload.end_time,
        )

        try:
            await self.repository.create(supervision)
            await self.repository.commit()

        except IntegrityError as err:
            await self.session.rollback()
            gender = await PersonRepository(self.session).gender(
                payload.teacher_tax_code
            )

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_CREATE_ERRORS[gender].for_request(),
            ) from err

        return supervision

    async def update(
        self,
        identity: IdentityContext,
        supervision_id: int,
        payload: RoomSupervisionUpdate,
    ) -> RoomSupervision:
        supervision = await self.get_or_404(supervision_id)

        assert_not_stale(
            supervision,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL.for_request(),
        )

        # Both the old and the new position are affected bands.
        await self._assert_claimed(
            identity,
            supervision.date,
            supervision.start_time,
            supervision.end_time,
        )
        await self._assert_claimed(
            identity,
            supervision.date,
            payload.start_time,
            payload.end_time,
        )

        await self._assert_within_availability(
            supervision.date,
            supervision.teacher_tax_code,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            supervision.date,
            supervision.teacher_tax_code,
            payload.start_time,
            payload.end_time,
            exclude_id=supervision.id,
        )

        supervision.assignment_start = await self._assignment_start(
            supervision.date,
            supervision.teacher_tax_code,
            supervision.room_id,
            payload.start_time,
            payload.end_time,
        )
        supervision.start_time = payload.start_time
        supervision.end_time = payload.end_time

        async with integrity_guard(self.session, _UPDATE_ERROR.for_request()):
            await self.repository.commit()
            await self.repository.refresh(supervision)

        return supervision

    # Gaps left behind are caught at publication; any ordering is allowed.
    async def delete(self, identity: IdentityContext, supervision_id: int) -> None:
        supervision = await self.get_or_404(supervision_id)

        await self._assert_claimed(
            identity,
            supervision.date,
            supervision.start_time,
            supervision.end_time,
        )

        await self.repository.delete(supervision)
        await self.repository.commit()
