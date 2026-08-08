from __future__ import annotations

from collections.abc import Sequence
from datetime import date, time

from sqlalchemy import delete, func, select

from app.models.opening_day import OpeningDay
from app.repositories.base import WritableRepository


class OpeningDayRepository(WritableRepository[OpeningDay]):
    async def list(
        self,
        *,
        date_from: date | None,
        date_to: date | None,
        mode: str | None,
    ) -> Sequence[OpeningDay]:
        stmt = select(OpeningDay).order_by(
            OpeningDay.date,
            OpeningDay.mode,
            OpeningDay.start_time,
        )

        if date_from is not None:
            stmt = stmt.where(OpeningDay.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(OpeningDay.date <= date_to)

        if mode is not None:
            stmt = stmt.where(OpeningDay.mode == mode)

        return (await self.session.execute(stmt)).scalars().all()

    async def get_by_id(self, opening_day_id: int) -> OpeningDay | None:
        return await self.session.get(OpeningDay, opening_day_id)

    async def create_many(self, opening_days: Sequence[OpeningDay]) -> None:
        self.session.add_all(opening_days)
        await self.session.flush()

    async def delete_for_date_mode(self, target_date: date, mode: str) -> None:
        stmt = delete(OpeningDay).where(
            OpeningDay.date == target_date,
            OpeningDay.mode == mode,
        )

        await self.session.execute(stmt)
        await self.session.flush()

    async def delete_for_range_mode(
        self,
        *,
        date_from: date,
        date_to: date,
        mode: str,
    ) -> None:
        stmt = delete(OpeningDay).where(
            OpeningDay.date >= date_from,
            OpeningDay.date <= date_to,
            OpeningDay.mode == mode,
        )

        await self.session.execute(stmt)
        await self.session.flush()

    async def existing_slot_keys(
        self,
        date_from: date,
        date_to: date,
    ) -> set[tuple[date, str, time | None]]:
        stmt = select(OpeningDay.date, OpeningDay.mode, OpeningDay.start_time).where(
            OpeningDay.date >= date_from,
            OpeningDay.date <= date_to,
        )

        rows = (await self.session.execute(stmt)).all()

        return {(row.date, row.mode, row.start_time) for row in rows}

    async def last_generated_date(self, mode: str) -> date | None:
        # How far the rows have already been generated: it bounds how far a
        # newly created template row is worth propagating.
        stmt = select(func.max(OpeningDay.date)).where(OpeningDay.mode == mode)

        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def dates_with_override(
        self,
        *,
        mode: str,
        date_from: date,
        date_to: date,
    ) -> set[date]:
        # Dates carrying an override (holiday, closure or extraordinary
        # opening) are left alone by propagation: an override always takes
        # precedence over the standard hours.
        stmt = select(OpeningDay.date).where(
            OpeningDay.mode == mode,
            OpeningDay.is_override.is_(True),
            OpeningDay.date >= date_from,
            OpeningDay.date <= date_to,
        )

        return {row.date for row in (await self.session.execute(stmt)).all()}

    # Drops the generated (non-override) rows of those dates, so a day can be
    # rewritten from the templates instead of patched row by row. Overrides stay
    # where they are, because they do not come from the templates.
    async def delete_generated_for_dates(
        self,
        dates: Sequence[date],
        mode: str,
    ) -> None:
        if not dates:
            return

        stmt = delete(OpeningDay).where(
            OpeningDay.date.in_(list(dates)),
            OpeningDay.mode == mode,
            OpeningDay.is_override.is_(False),
        )

        await self.session.execute(stmt)
        await self.session.flush()

    async def delete_many(self, opening_days: Sequence[OpeningDay]) -> None:
        for opening_day in opening_days:
            await self.session.delete(opening_day)

        await self.session.flush()
