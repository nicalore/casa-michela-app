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
from app.services.enrollment_spans import (
    EnrolledSpan,
    enrollment_within,
    is_enrolled_on,
)

_WEEK: Final[timedelta] = timedelta(days=7)


def _monday_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


# A Monday-to-Sunday week the association opens at least once in the mode.
@dataclass(frozen=True, slots=True)
class WeekFrame:
    monday: date

    # Fewer than the threshold only when the association opens fewer days.
    required: int

    # Openings remain from today on, so the week is not judged yet.
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


# One mode's openings by Monday, whole weeks begun by today opening in [start, end).
@dataclass(frozen=True, slots=True)
class OpeningWeeks:
    start: date
    end: date
    today: date
    openings: Mapping[date, tuple[date, ...]]

    # A week across two months belongs to both, unless it opens in only one of them.
    # Given spans, only openings while enrolled count.
    def frames(self, spans: Sequence[EnrolledSpan] | None = None) -> list[WeekFrame]:
        frames = []

        for monday, days in self.openings.items():
            if spans is not None:
                days = tuple(day for day in days if is_enrolled_on(day, spans))
                joined = enrollment_within(spans, monday, monday + _WEEK)

                # The week one enrolls in needs two openings left after that day.
                if joined is not None and (
                    sum(1 for day in days if day > joined)
                    < LOW_AVAILABILITY_WEEKLY_THRESHOLD
                ):
                    continue

            if any(self.start <= day < self.end for day in days):
                frames.append(
                    WeekFrame(
                        monday=monday,
                        required=min(LOW_AVAILABILITY_WEEKLY_THRESHOLD, len(days)),
                        is_open=max(days) >= self.today,
                    ),
                )

        return frames


async def opening_weeks(
    db: AsyncSession,
    start: date,
    end: date,
    today: date,
    mode: str = "presence",
) -> OpeningWeeks:
    until = min(end, today + timedelta(days=1))

    if until <= start:
        return OpeningWeeks(start=start, end=end, today=today, openings={})

    first = _monday_of(start)
    last = _monday_of(until - timedelta(days=1))

    open_days = await db.scalars(
        select(OpeningDay.date)
        .distinct()
        .where(
            OpeningDay.mode == mode,
            OpeningDay.start_time.is_not(None),
            OpeningDay.date >= first,
            OpeningDay.date < last + _WEEK,
        ),
    )

    by_week: dict[date, list[date]] = defaultdict(list)

    for day in open_days:
        by_week[_monday_of(day)].append(day)

    return OpeningWeeks(
        start=start,
        end=end,
        today=today,
        openings={
            monday: tuple(sorted(days))
            for monday, days in sorted(by_week.items())
            if any(start <= day < end for day in days)
        },
    )


# Days given per teacher and week, future days included.
async def days_given(
    db: AsyncSession,
    weeks: OpeningWeeks,
    tax_code: str | None = None,
    mode: str = "presence",
) -> dict[str, dict[date, int]]:
    if not weeks.openings:
        return {}

    mondays = list(weeks.openings)

    stmt = (
        select(Availability.teacher_tax_code, Availability.date)
        .distinct()
        .where(
            Availability.mode == mode,
            Availability.date >= mondays[0],
            Availability.date < mondays[-1] + _WEEK,
        )
    )

    if tax_code is not None:
        stmt = stmt.where(Availability.teacher_tax_code == tax_code)

    given: dict[str, dict[date, int]] = defaultdict(lambda: defaultdict(int))

    for teacher, day in await db.execute(stmt):
        monday = _monday_of(day)

        if monday in weeks.openings:
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


# Only the weeks the teacher was enrolled in, each asking for its enrolled openings.
async def teacher_weeks(
    db: AsyncSession,
    tax_code: str,
    spans: Sequence[EnrolledSpan],
    start: date,
    end: date,
    today: date,
    mode: str = "presence",
) -> list[AvailabilityWeek]:
    weeks = await opening_weeks(db, start, end, today, mode)
    given = await days_given(db, weeks, tax_code, mode)

    return weeks_of(weeks.frames(spans), given.get(tax_code, {}))


def weekly_average(weeks: Sequence[AvailabilityWeek]) -> float:
    if not weeks:
        return 0.0

    return sum(week.given for week in weeks) / len(weeks)
