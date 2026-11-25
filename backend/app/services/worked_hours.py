from collections import defaultdict
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from datetime import date, time, timedelta
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.services.enrollment_spans import hours_spans, is_enrolled_on

MINUTES_PER_HOUR: Final[int] = 60

# The association's first month: accounting reaches back to it, with no limit.
BEGINNING: Final[date] = date(2023, 1, 1)

Stretch = tuple[date, time, time]

# Teacher, day, band, mode and times of one published lesson or activity.
CalendarRow = tuple[str, date, str, str, time, time]

# Minutes from midnight, end excluded.
Span = tuple[int, int]

PRESENCE: Final[str] = "presence"
ONLINE: Final[str] = "online"

BAND_ORDER: Final[dict[str, int]] = {"MORNING": 0, "AFTERNOON": 1, "EVENING": 2}


# A teacher's band as pay reads it: in person the time between two lessons
# is paid, online only the lessons are.
@dataclass(frozen=True)
class BandWork:
    day: date
    band: str
    presence: bool
    spans: list[Span]
    # Written by hand and confirmed; None leaves it to the month's rule.
    volunteer: list[Span] | None = None

    @property
    def key(self) -> tuple[date, int]:
        return band_key(self.day, self.band)


def band_key(day: date, band: str) -> tuple[date, int]:
    return (day, BAND_ORDER[band])


def minutes_of(moment: time) -> int:
    return moment.hour * MINUTES_PER_HOUR + moment.minute


def time_of(minutes: int) -> time:
    return time(minutes // MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR)


def month_after(month: date) -> date:
    return (month + timedelta(days=32)).replace(day=1)


# Lessons may overlap: a union, not a sum.
def merge(spans: Iterable[Span]) -> list[Span]:
    kept: list[Span] = []

    for start, end in sorted(spans):
        if kept and start <= kept[-1][1]:
            kept[-1] = (kept[-1][0], max(kept[-1][1], end))
        else:
            kept.append((start, end))

    return kept


def merged_spans(stretches: Iterable[Stretch]) -> dict[date, list[Span]]:
    by_day: dict[date, list[Span]] = defaultdict(list)

    for day, start, end in stretches:
        by_day[day].append((minutes_of(start), minutes_of(end)))

    return {day: merge(spans) for day, spans in by_day.items()}


# One mode per teacher per band; an activity in person makes it so.
def work_of(rows: Iterable[tuple[str, time, time]]) -> tuple[bool, list[Span]]:
    listed = list(rows)
    spans = [(minutes_of(start), minutes_of(end)) for _, start, end in listed]
    presence = any(mode == PRESENCE for mode, _, _ in listed)

    if presence:
        return True, [(min(start for start, _ in spans), max(end for _, end in spans))]

    return False, merge(spans)


def band_work(rows: Iterable[CalendarRow]) -> list[BandWork]:
    by_band: dict[tuple[date, str], list[tuple[str, time, time]]] = defaultdict(list)

    for _, day, band, mode, start, end in rows:
        by_band[(day, band)].append((mode, start, end))

    bands = []

    for (day, band), listed in by_band.items():
        presence, spans = work_of(listed)
        bands.append(BandWork(day=day, band=band, presence=presence, spans=spans))

    return sorted(bands, key=lambda work: work.key)


def days_of(bands: Iterable[BandWork]) -> dict[date, list[Span]]:
    by_day: dict[date, list[Span]] = defaultdict(list)

    for work in bands:
        by_day[work.day].extend(work.spans)

    return {day: merge(spans) for day, spans in sorted(by_day.items())}


def span_minutes(spans: Iterable[Span]) -> int:
    return sum(end - start for start, end in spans)


async def published_pairs(
    db: AsyncSession,
    start: date,
    end: date,
) -> set[tuple[date, str]]:
    rows = await db.execute(
        select(CalendarPublication.date, CalendarPublication.band).where(
            CalendarPublication.date >= start,
            CalendarPublication.date < end,
        ),
    )

    return {(row.date, row.band) for row in rows}


# Published ones; one teacher's, or everybody's without a tax code. Room shifts
# are left out: they may lag behind the lessons they cover.
async def _published_rows(
    db: AsyncSession,
    start: date,
    end: date,
    tax_code: str | None,
) -> list[CalendarRow]:
    taught = (
        []
        if tax_code is None
        else [Availability.teacher_tax_code == tax_code]
    )

    lessons = await db.execute(
        select(
            Availability.teacher_tax_code,
            Lesson.date,
            Lesson.band,
            Lesson.teacher_mode,
            Lesson.start_time,
            Lesson.end_time,
        )
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(*taught, Lesson.date >= start, Lesson.date < end),
    )

    activities = await db.execute(
        select(
            Availability.teacher_tax_code,
            CalendarActivity.date,
            CalendarActivity.band,
            Availability.mode,
            CalendarActivity.start_time,
            CalendarActivity.end_time,
        )
        .join(Availability, Availability.id == CalendarActivity.availability_id)
        .where(*taught, CalendarActivity.date >= start, CalendarActivity.date < end),
    )

    published = await published_pairs(db, start, end)
    rows = [*lessons.tuples(), *activities.tuples()]

    return [row for row in rows if (row[1], row[2]) in published]


# Published and over: what the teacher has actually done, from start up to end.
# Accounting reads these for good: never prune them by age.
async def teacher_rows(
    db: AsyncSession,
    tax_code: str,
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
) -> list[CalendarRow]:
    rows = await _published_rows(db, start, end, tax_code)

    return [row for row in rows if is_over(row[1], row[5])]


# When each published band's last lesson or activity ends, over [start, end).
async def band_last_ends(
    db: AsyncSession,
    start: date,
    end: date,
) -> dict[tuple[date, str], time]:
    rows = await _published_rows(db, start, end, None)
    # As the daily summary: nobody has hours on a day they were not enrolled.
    spans = await hours_spans(db, {row[0] for row in rows})
    ends: dict[tuple[date, str], time] = {}

    for teacher, day, band, _, _, finish in rows:
        if not is_enrolled_on(day, spans.get(teacher, [])):
            continue

        key = (day, band)
        ends[key] = max(ends.get(key, finish), finish)

    return ends


# What the calendar says of a band, teacher by teacher: where an admin starts from.
async def band_rows(
    db: AsyncSession,
    day: date,
    band: str,
) -> dict[str, list[CalendarRow]]:
    by_teacher: dict[str, list[CalendarRow]] = defaultdict(list)

    for row in await _published_rows(db, day, day + timedelta(days=1), None):
        if row[2] == band:
            by_teacher[row[0]].append(row)

    return dict(by_teacher)
