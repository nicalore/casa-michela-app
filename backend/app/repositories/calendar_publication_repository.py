from __future__ import annotations

from collections.abc import Collection, Sequence
from datetime import date

from sqlalchemy import select

from app.models.calendar_publication import CalendarPublication
from app.repositories.base import WritableRepository


class CalendarPublicationRepository(WritableRepository[CalendarPublication]):
    async def list(
        self,
        *,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> Sequence[CalendarPublication]:
        stmt = select(CalendarPublication).order_by(
            CalendarPublication.date,
            CalendarPublication.band,
        )

        if date_from is not None:
            stmt = stmt.where(CalendarPublication.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(CalendarPublication.date <= date_to)

        return (await self.session.execute(stmt)).scalars().all()

    async def get(self, day: date, band: str) -> CalendarPublication | None:
        return await self.session.scalar(
            select(CalendarPublication).where(
                CalendarPublication.date == day,
                CalendarPublication.band == band,
            ),
        )

    # Row lock held for the transaction: the band lock does not cover one
    # administrator with two windows open.
    async def get_for_update(self, day: date, band: str) -> CalendarPublication | None:
        return await self.session.scalar(
            select(CalendarPublication)
            .where(
                CalendarPublication.date == day,
                CalendarPublication.band == band,
            )
            .with_for_update(),
        )

    async def is_published(self, day: date, band: str) -> bool:
        return await self.get(day, band) is not None

    async def find_published_bands(self, day: date) -> set[str]:
        rows = await self.session.scalars(
            select(CalendarPublication.band).where(
                CalendarPublication.date == day,
            ),
        )

        return set(rows)

    async def find_settled_pairs(
        self,
        pairs: Collection[tuple[date, str]],
    ) -> set[tuple[date, str]]:
        if not pairs:
            return set()

        days = {day for day, _ in pairs}

        rows = (
            await self.session.execute(
                select(CalendarPublication.date, CalendarPublication.band).where(
                    CalendarPublication.date.in_(days),
                    CalendarPublication.draft_snapshot.is_(None),
                ),
            )
        ).all()

        stored = {(day, band) for day, band in rows}

        return stored & set(pairs)
