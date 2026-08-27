from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta

from sqlalchemy import Interval, case, delete, func, literal, or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.sql.elements import ColumnElement

from app.models.calendar_band_lock import LOCK_TTL_SECONDS, CalendarBandLock
from app.repositories.base import WritableRepository


# Liveness is judged by the database clock, never an application-side clock.
def _alive() -> ColumnElement[bool]:
    return CalendarBandLock.heartbeat_at > func.now() - literal(
        timedelta(seconds=LOCK_TTL_SECONDS),
        Interval(),
    )


class CalendarBandLockRepository(WritableRepository[CalendarBandLock]):
    # Atomic claim-or-renew: two concurrent claimers cannot both win.
    # None means the band is held alive by someone else.
    async def claim(
        self,
        day: date,
        band: str,
        tax_code: str,
    ) -> CalendarBandLock | None:
        stmt = (
            insert(CalendarBandLock)
            .values(date=day, band=band, holder_tax_code=tax_code)
            .on_conflict_do_update(
                index_elements=[CalendarBandLock.date, CalendarBandLock.band],
                set_={
                    "holder_tax_code": tax_code,
                    # Renewal keeps acquired_at; taking over an expired lock resets it.
                    "acquired_at": case(
                        (
                            CalendarBandLock.holder_tax_code == tax_code,
                            CalendarBandLock.acquired_at,
                        ),
                        else_=func.now(),
                    ),
                    "heartbeat_at": func.now(),
                },
                where=or_(
                    CalendarBandLock.holder_tax_code == tax_code,
                    ~_alive(),
                ),
            )
            .returning(CalendarBandLock)
        )

        return (await self.session.scalars(stmt)).first()

    async def holder(self, day: date, band: str) -> CalendarBandLock | None:
        return await self.session.scalar(
            select(CalendarBandLock).where(
                CalendarBandLock.date == day,
                CalendarBandLock.band == band,
                _alive(),
            ),
        )

    async def live(
        self,
        *,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> Sequence[CalendarBandLock]:
        stmt = (
            select(CalendarBandLock)
            .where(_alive())
            .order_by(CalendarBandLock.date, CalendarBandLock.band)
        )

        if date_from is not None:
            stmt = stmt.where(CalendarBandLock.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(CalendarBandLock.date <= date_to)

        return (await self.session.execute(stmt)).scalars().all()

    # Deletes only the caller's own lock.
    async def release(self, day: date, band: str, tax_code: str) -> None:
        await self.session.execute(
            delete(CalendarBandLock).where(
                CalendarBandLock.date == day,
                CalendarBandLock.band == band,
                CalendarBandLock.holder_tax_code == tax_code,
            ),
        )
        await self.session.flush()
