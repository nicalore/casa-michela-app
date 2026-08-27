from __future__ import annotations

from collections.abc import Sequence
from datetime import time

from sqlalchemy import select

from app.models.weekly_template import WeeklyTemplate
from app.repositories.base import WritableRepository


class WeeklyTemplateRepository(WritableRepository[WeeklyTemplate]):
    async def list(self) -> Sequence[WeeklyTemplate]:
        stmt = select(WeeklyTemplate).order_by(
            WeeklyTemplate.weekday,
            WeeklyTemplate.mode,
            WeeklyTemplate.start_time,
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def list_by_weekday(self, weekday: int) -> Sequence[WeeklyTemplate]:
        stmt = (
            select(WeeklyTemplate)
            .where(WeeklyTemplate.weekday == weekday)
            .order_by(WeeklyTemplate.mode, WeeklyTemplate.start_time)
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def get_by_id(self, template_id: int) -> WeeklyTemplate | None:
        return await self.session.get(WeeklyTemplate, template_id)

    async def get_by_slot(
        self,
        weekday: int,
        mode: str,
        start_time: time,
    ) -> WeeklyTemplate | None:
        # Natural-key lookup: finds an existing band instead of hitting the
        # unique constraint.
        stmt = select(WeeklyTemplate).where(
            WeeklyTemplate.weekday == weekday,
            WeeklyTemplate.mode == mode,
            WeeklyTemplate.start_time == start_time,
        )

        return await self.session.scalar(stmt)
