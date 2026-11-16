from collections import defaultdict
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.confirmed_hours import (
    ConfirmedBand,
    ConfirmedHours,
    ConfirmedVolunteering,
)
from app.services.worked_hours import (
    PRESENCE,
    BandWork,
    Span,
    merge,
    minutes_of,
    time_of,
)


# One teacher's hours as a confirmation fixes them. Volunteering is kept only when
# written by hand (None then is none at all); otherwise the month's rule gives it.
@dataclass(frozen=True)
class ConfirmedRow:
    spans: list[Span]
    mode: str = PRESENCE
    volunteer: Span | None = None
    volunteer_set: bool = False


async def confirmed_bands(
    db: AsyncSession,
    start: date,
    end: date,
) -> set[tuple[date, str]]:
    rows = await db.execute(
        select(ConfirmedBand.date, ConfirmedBand.band).where(
            ConfirmedBand.date >= start,
            ConfirmedBand.date < end,
        ),
    )

    return {(row.date, row.band) for row in rows}


async def confirmed_work(
    db: AsyncSession,
    tax_code: str,
    start: date,
    end: date,
) -> list[BandWork]:
    hours = await db.execute(
        select(
            ConfirmedHours.date,
            ConfirmedHours.band,
            ConfirmedHours.mode,
            ConfirmedHours.start_time,
            ConfirmedHours.end_time,
        ).where(
            ConfirmedHours.teacher_tax_code == tax_code,
            ConfirmedHours.date >= start,
            ConfirmedHours.date < end,
        ),
    )

    given = await db.execute(
        select(
            ConfirmedVolunteering.date,
            ConfirmedVolunteering.band,
            ConfirmedVolunteering.start_time,
            ConfirmedVolunteering.end_time,
        ).where(
            ConfirmedVolunteering.teacher_tax_code == tax_code,
            ConfirmedVolunteering.date >= start,
            ConfirmedVolunteering.date < end,
        ),
    )

    spans: dict[tuple[date, str], list[Span]] = defaultdict(list)
    modes: dict[tuple[date, str], str] = {}
    volunteer: dict[tuple[date, str], list[Span]] = {}

    for day, band, mode, start_time, end_time in hours.tuples():
        spans[(day, band)].append((minutes_of(start_time), minutes_of(end_time)))
        modes[(day, band)] = mode

    for day, band, start_time, end_time in given.tuples():
        listed = volunteer.setdefault((day, band), [])

        if start_time is not None and end_time is not None:
            listed.append((minutes_of(start_time), minutes_of(end_time)))

    return sorted(
        (
            BandWork(
                day=day,
                band=band,
                presence=modes[(day, band)] == PRESENCE,
                spans=merge(listed),
                volunteer=volunteer.get((day, band)),
            )
            for (day, band), listed in spans.items()
        ),
        key=lambda work: work.key,
    )


# Again on the same band, the new hours replace the old.
# A teacher left out has worked nothing in it, whatever the calendar says.
async def confirm_band(
    db: AsyncSession,
    day: date,
    band: str,
    rows: Mapping[str, ConfirmedRow],
    *,
    by: str | None = None,
    at: datetime | None = None,
) -> None:
    await db.execute(
        delete(ConfirmedBand).where(
            ConfirmedBand.date == day,
            ConfirmedBand.band == band,
        ),
    )

    confirmed = ConfirmedBand(date=day, band=band, confirmed_by_tax_code=by)

    if at is not None:
        confirmed.confirmed_at = at

    db.add(confirmed)
    await db.flush()

    db.add_all(
        ConfirmedHours(
            teacher_tax_code=tax_code,
            date=day,
            band=band,
            mode=row.mode,
            start_time=time_of(start),
            end_time=time_of(end),
        )
        for tax_code, row in rows.items()
        for start, end in merge(row.spans)
    )

    db.add_all(
        ConfirmedVolunteering(
            teacher_tax_code=tax_code,
            date=day,
            band=band,
            start_time=None if row.volunteer is None else time_of(row.volunteer[0]),
            end_time=None if row.volunteer is None else time_of(row.volunteer[1]),
        )
        for tax_code, row in rows.items()
        if row.volunteer_set
    )

    await db.flush()
