from collections import defaultdict
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.availability_thresholds import LOW_AVAILABILITY_WEEKLY_THRESHOLD
from app.models.availability import Availability
from app.models.opening_day import OpeningDay

_WEEK: Final[timedelta] = timedelta(days=7)


def _monday_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


# A Monday-to-Sunday week the association opens at least once in presence.
@dataclass(frozen=True, slots=True)
class WeekFrame:
    monday: date

    # Fewer than the threshold only when the association opens fewer days.
    required: int

    # Openings left from today on: days can still be given, so it is not judged.
    is_open: bool


@dataclass(frozen=True, slots=True)
class AvailabilityWeek:
    monday: date
    required: int
    is_open: bool
    given: int

    @property
    def is_short(self) -> bool:
        return not self.is_open and self.given < self.required


# Weeks begun by today that open inside [start, end), each read whole: a week across
# two months belongs to both, unless it opens in only one of them.
async def week_frames(
    db: AsyncSession,
    start: date,
    end: date,
    today: date,
) -> list[WeekFrame]:
    until = min(end, today + timedelta(days=1))

    if until <= start:
        return []

    first = _monday_of(start)
    last = _monday_of(until - timedelta(days=1))

    open_days = await db.scalars(
        select(OpeningDay.date)
        .distinct()
        .where(
            OpeningDay.mode == "presence",
            OpeningDay.start_time.is_not(None),
            OpeningDay.date >= first,
            OpeningDay.date < last + _WEEK,
        ),
    )

    by_week: dict[date, list[date]] = defaultdict(list)

    for day in open_days:
        by_week[_monday_of(day)].append(day)

    return [
        WeekFrame(
            monday=monday,
            required=min(LOW_AVAILABILITY_WEEKLY_THRESHOLD, len(days)),
            is_open=max(days) >= today,
        )
        for monday, days in sorted(by_week.items())
        if any(start <= day < end for day in days)
    ]


# Days given in presence per teacher and week, days ahead of today included.
async def days_given(
    db: AsyncSession,
    frames: Sequence[WeekFrame],
    tax_code: str | None = None,
) -> dict[str, dict[date, int]]:
    if not frames:
        return {}

    stmt = (
        select(Availability.teacher_tax_code, Availability.date)
        .distinct()
        .where(
            Availability.mode == "presence",
            Availability.date >= frames[0].monday,
            Availability.date < frames[-1].monday + _WEEK,
        )
    )

    if tax_code is not None:
        stmt = stmt.where(Availability.teacher_tax_code == tax_code)

    counted = {frame.monday for frame in frames}
    given: dict[str, dict[date, int]] = defaultdict(lambda: defaultdict(int))

    for teacher, day in await db.execute(stmt):
        monday = _monday_of(day)

        if monday in counted:
            given[teacher][monday] += 1

    return given


def weeks_of(
    frames: Sequence[WeekFrame],
    given: Mapping[date, int],
) -> list[AvailabilityWeek]:
    return [
        AvailabilityWeek(
            monday=frame.monday,
            required=frame.required,
            is_open=frame.is_open,
            given=given.get(frame.monday, 0),
        )
        for frame in frames
    ]


async def teacher_weeks(
    db: AsyncSession,
    tax_code: str,
    start: date,
    end: date,
    today: date,
) -> list[AvailabilityWeek]:
    frames = await week_frames(db, start, end, today)
    given = await days_given(db, frames, tax_code)

    return weeks_of(frames, given.get(tax_code, {}))


def weekly_average(weeks: Sequence[AvailabilityWeek]) -> float:
    if not weeks:
        return 0.0

    return sum(week.given for week in weeks) / len(weeks)
