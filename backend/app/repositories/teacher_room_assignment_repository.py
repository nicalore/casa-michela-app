from __future__ import annotations

from collections.abc import Collection, Sequence
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.base import WritableRepository

_EAGER_LOADER = (selectinload(TeacherRoomAssignment.room),)


class TeacherRoomAssignmentRepository(WritableRepository[TeacherRoomAssignment]):
    async def list_for_day(self, day: date) -> Sequence[TeacherRoomAssignment]:
        stmt = (
            select(TeacherRoomAssignment)
            .options(*_EAGER_LOADER)
            .where(TeacherRoomAssignment.date == day)
            .order_by(TeacherRoomAssignment.teacher_tax_code)
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def get(
        self,
        day: date,
        teacher_tax_code: str,
    ) -> TeacherRoomAssignment | None:
        stmt = (
            select(TeacherRoomAssignment)
            .options(*_EAGER_LOADER)
            .where(
                TeacherRoomAssignment.date == day,
                TeacherRoomAssignment.teacher_tax_code == teacher_tax_code,
            )
        )

        return await self.session.scalar(stmt)

    async def find_for_teachers(
        self,
        day: date,
        teacher_tax_codes: Collection[str],
    ) -> Sequence[TeacherRoomAssignment]:
        if not teacher_tax_codes:
            return []

        stmt = (
            select(TeacherRoomAssignment)
            .options(*_EAGER_LOADER)
            .where(
                TeacherRoomAssignment.date == day,
                TeacherRoomAssignment.teacher_tax_code.in_(teacher_tax_codes),
            )
        )

        return (await self.session.execute(stmt)).scalars().all()

    # Shifts are removed here rather than by the cascade so the service can
    # report how many were taken away.
    async def count_supervisions(self, day: date, teacher_tax_code: str) -> int:
        rows = await self.session.scalars(
            select(RoomSupervision.id).where(
                RoomSupervision.date == day,
                RoomSupervision.teacher_tax_code == teacher_tax_code,
            ),
        )

        return len(list(rows))
