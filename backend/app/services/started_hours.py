from __future__ import annotations

from collections.abc import Iterable, Sequence
from datetime import date, datetime, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import now_in_rome
from app.core.labels import opening_mode_label, time_band_phrase
from app.core.time_band import DAY_END, DAY_START, band_of
from app.models.opening_day import OpeningDay

_STARTED_ERROR: Final[str] = (
    "Gli orari {mode} {band} del {day} sono già iniziati: "
    "non si possono più cambiare."
)

type HoursByBand = dict[tuple[date, str], frozenset[tuple[time, time]]]


async def _hours_of(
    session: AsyncSession,
    days: Sequence[date],
    mode: str,
) -> HoursByBand:
    rows = (
        (
            await session.execute(
                select(OpeningDay).where(
                    OpeningDay.date.in_(days),
                    OpeningDay.mode == mode,
                    OpeningDay.start_time.is_not(None),
                ),
            )
        )
        .scalars()
        .all()
    )

    hours: HoursByBand = {}

    for row in rows:
        start = row.start_time
        end = row.end_time

        if start is None or end is None or start < DAY_START or start >= DAY_END:
            continue

        key = (row.date, str(band_of(start)))
        hours[key] = hours.get(key, frozenset()) | {(start, end)}

    return hours


# Refuses a write that changes a band whose hours, old or new, have begun.
class StartedHoursGuard:
    def __init__(
        self,
        session: AsyncSession,
        days: Sequence[date],
        mode: str,
        before: HoursByBand,
    ) -> None:
        self.session = session
        self.days = days
        self.mode = mode
        self.before = before

    @classmethod
    async def taken(
        cls,
        session: AsyncSession,
        dates: Iterable[date],
        mode: str,
    ) -> StartedHoursGuard:
        days = sorted(set(dates))

        return cls(session, days, mode, await _hours_of(session, days, mode))

    # After the write, before commit; a refusal leaves the transaction to roll back.
    async def settle(self) -> None:
        after = await _hours_of(self.session, self.days, self.mode)
        now = now_in_rome()
        started: list[tuple[date, time, str]] = []

        for day, band in self.before.keys() | after.keys():
            was = self.before.get((day, band), frozenset())
            becomes = after.get((day, band), frozenset())

            if was == becomes:
                continue

            starts = min(start for start, _ in was | becomes)

            if datetime.combine(day, starts, tzinfo=now.tzinfo) <= now:
                started.append((day, starts, band))

        if not started:
            return

        day, _, band = min(started)

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_STARTED_ERROR.format(
                mode=opening_mode_label(self.mode),
                band=time_band_phrase(band),
                day=day.strftime("%d/%m/%Y"),
            ),
        )
