from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select

from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.models.availability import Availability
from app.models.room_supervision import RoomSupervision
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.room_supervision import (
    RoomSupervisionCreate,
    RoomSupervisionUpdate,
)

_ENTITY_LABEL: Final[str] = "il turno"
_NOT_FOUND_ERROR: Final[str] = "Turno da responsabile non trovato"
_CREATE_ERROR: Final[str] = (
    "Il docente non ha questa stanza assegnata in questa giornata."
)
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_NOT_ASSIGNED_ERROR: Final[str] = (
    "Solo un docente assegnato a questa stanza può esserne responsabile."
)

_OUTSIDE_AVAILABILITY_ERROR: Final[str] = (
    "Il turno deve rientrare nelle disponibilità in presenza del docente in "
    "questa giornata."
)

_OVERLAPPING_SHIFT_ERROR: Final[str] = (
    "Il docente ha già un turno da responsabile sovrapposto a quest'orario."
)


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

    # The composite foreign key already makes this impossible; the check is here
    # for the sentence, so the answer is not a bare integrity error.
    async def _assert_assigned(
        self,
        day: date,
        teacher_tax_code: str,
        room_id: int,
    ) -> None:
        assignment = await self.assignments.get(day, teacher_tax_code)

        if assignment is None or assignment.room_id != room_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_ASSIGNED_ERROR,
            )

    # Whoever watches over a room is in the building, so the shift has to fall
    # inside hours the teacher actually offered there. Checked against the union
    # of their in-person stretches, which may be several across a day.
    async def _assert_within_availability(
        self,
        day: date,
        teacher_tax_code: str,
        start_time: time,
        end_time: time,
    ) -> None:
        stretches = (
            await self.session.execute(
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

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_OUTSIDE_AVAILABILITY_ERROR,
        )

    # Across the whole day and not within one room: nobody answers for two
    # rooms at the same time.
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
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OVERLAPPING_SHIFT_ERROR,
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
                detail=_NOT_FOUND_ERROR,
            )

        return supervision

    async def create(self, payload: RoomSupervisionCreate) -> RoomSupervision:
        await self._assert_assigned(
            payload.date,
            payload.teacher_tax_code,
            payload.room_id,
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
            start_time=payload.start_time,
            end_time=payload.end_time,
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(supervision)
            await self.repository.commit()

        return supervision

    async def update(
        self,
        supervision_id: int,
        payload: RoomSupervisionUpdate,
    ) -> RoomSupervision:
        supervision = await self.get_or_404(supervision_id)

        assert_not_stale(
            supervision,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
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

        supervision.start_time = payload.start_time
        supervision.end_time = payload.end_time

        async with integrity_guard(self.session, _UPDATE_ERROR):
            await self.repository.commit()
            await self.repository.refresh(supervision)

        return supervision

    # No precondition beyond existing: a gap left behind is caught when the band
    # is published, and arranging shifts in whatever order suits is the point.
    async def delete(self, supervision_id: int) -> None:
        supervision = await self.get_or_404(supervision_id)

        await self.repository.delete(supervision)
        await self.repository.commit()
