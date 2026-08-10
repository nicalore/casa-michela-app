from __future__ import annotations

from collections.abc import Sequence

from sqlalchemy import func, select

from app.models.room import Room
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.base import WritableRepository


class RoomRepository(WritableRepository[Room]):
    async def list(self) -> Sequence[Room]:
        return (
            (await self.session.execute(select(Room).order_by(Room.name)))
            .scalars()
            .all()
        )

    async def get_by_id(self, room_id: int) -> Room | None:
        return await self.session.scalar(select(Room).where(Room.id == room_id))

    async def find_by_ids(self, room_ids: Sequence[int]) -> Sequence[Room]:
        if not room_ids:
            return []

        return (
            (await self.session.execute(select(Room).where(Room.id.in_(room_ids))))
            .scalars()
            .all()
        )

    # Case-insensitive, because the UNIQUE alone would let "Aula blu" stand
    # beside "Aula Blu" and nobody would know which one they were sent to.
    async def find_by_name(
        self,
        name: str,
        *,
        exclude_id: int | None = None,
    ) -> Room | None:
        stmt = select(Room).where(Room.name.ilike(name))

        if exclude_id is not None:
            stmt = stmt.where(Room.id != exclude_id)

        return await self.session.scalar(stmt)

    async def count_assignments(self, room_id: int) -> int:
        return (
            await self.session.scalar(
                select(func.count())
                .select_from(TeacherRoomAssignment)
                .where(TeacherRoomAssignment.room_id == room_id),
            )
            or 0
        )
