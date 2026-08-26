from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta

from sqlalchemy import Interval, case, delete, func, literal, or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.sql.elements import ColumnElement

from app.models.calendar_band_lock import LOCK_TTL_SECONDS, CalendarBandLock
from app.repositories.base import WritableRepository


# Whether the lock is still worth anything, asked of the database and never of a
# clock on this side of it: two callers cannot disagree about it, and no browser
# can lie about it.
def _alive() -> ColumnElement[bool]:
    return CalendarBandLock.heartbeat_at > func.now() - literal(
        timedelta(seconds=LOCK_TTL_SECONDS),
        Interval(),
    )


class CalendarBandLockRepository(WritableRepository[CalendarBandLock]):
    # Takes the band, or renews it, in one statement: nothing separates the
    # question from the answer, so two administrators pressing in the same
    # instant cannot both be told yes.
    #
    # Nothing back means the band is somebody else's and they are still there.
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
                    # Renewing keeps the sitting that was already going; taking
                    # over an abandoned band starts a new one, because the hour
                    # the banner says is the hour this administrator arrived.
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

    # Only ever one's own: letting go is not the same as taking away, and an
    # expired row that somebody else has already taken is theirs now.
    async def release(self, day: date, band: str, tax_code: str) -> None:
        await self.session.execute(
            delete(CalendarBandLock).where(
                CalendarBandLock.date == day,
                CalendarBandLock.band == band,
                CalendarBandLock.holder_tax_code == tax_code,
            ),
        )
        await self.session.flush()
