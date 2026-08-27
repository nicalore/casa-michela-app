from __future__ import annotations

from collections.abc import Collection, Sequence
from datetime import date, time

from sqlalchemy import select

from app.models.room_supervision import RoomSupervision
from app.repositories.base import WritableRepository


class RoomSupervisionRepository(WritableRepository[RoomSupervision]):
    async def list_for_day(
        self,
        day: date,
        *,
        room_id: int | None = None,
    ) -> Sequence[RoomSupervision]:
        stmt = (
            select(RoomSupervision)
            .where(RoomSupervision.date == day)
            .order_by(RoomSupervision.room_id, RoomSupervision.start_time)
        )

        if room_id is not None:
            stmt = stmt.where(RoomSupervision.room_id == room_id)

        return (await self.session.execute(stmt)).scalars().all()

    async def get_by_id(self, supervision_id: int) -> RoomSupervision | None:
        return await self.session.scalar(
            select(RoomSupervision).where(RoomSupervision.id == supervision_id),
        )

    async def find_for_rooms(
        self,
        day: date,
        room_ids: Collection[int],
    ) -> Sequence[RoomSupervision]:
        if not room_ids:
            return []

        stmt = (
            select(RoomSupervision)
            .where(
                RoomSupervision.date == day,
                RoomSupervision.room_id.in_(room_ids),
            )
            .order_by(RoomSupervision.room_id, RoomSupervision.start_time)
        )

        return (await self.session.execute(stmt)).scalars().all()

    # Day-wide overlap check: nobody watches two rooms at once.
    async def find_teacher_overlap(
        self,
        *,
        day: date,
        teacher_tax_code: str,
        start_time: time,
        end_time: time,
        exclude_id: int | None = None,
    ) -> RoomSupervision | None:
        stmt = select(RoomSupervision).where(
            RoomSupervision.date == day,
            RoomSupervision.teacher_tax_code == teacher_tax_code,
            RoomSupervision.start_time < end_time,
            RoomSupervision.end_time > start_time,
        )

        if exclude_id is not None:
            stmt = stmt.where(RoomSupervision.id != exclude_id)

        return await self.session.scalar(stmt)
