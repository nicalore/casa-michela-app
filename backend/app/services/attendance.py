from collections import defaultdict
from collections.abc import Callable, Collection, Iterable
from dataclasses import dataclass
from datetime import date, time
from typing import Any

from sqlalchemy import CompoundSelect, Select, case, exists, select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import AFTERNOON_START, EVENING_START, TimeBandEnum
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.confirmed_hours import ConfirmedBand, ConfirmedHours
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.presence import Presence
from app.models.student_hours import StudentConfirmedBand, StudentConfirmedHours
from app.services.worked_hours import Span, merge, minutes_of, published_pairs

# Person, day and band.
BandKey = tuple[str, date, str]
# Per person, per day: merged stretches.
TimeByDay = dict[str, dict[date, list[Span]]]


# Who a daily summary confirmed in each band, and when.
@dataclass(frozen=True)
class ConfirmedTimes:
    bands: set[tuple[date, str]]
    spans: dict[BandKey, list[Span]]

    # In a confirmed band with no hours: marked absent, or never there.
    def absent(self, tax_code: str, day: date, band: str) -> bool:
        return (day, band) in self.bands and (tax_code, day, band) not in self.spans


def _times(
    bands: Iterable[tuple[date, str]],
    hours: Iterable[tuple[str, date, str, time, time]],
) -> ConfirmedTimes:
    listed: dict[BandKey, list[Span]] = defaultdict(list)

    for tax_code, day, band, start, end in hours:
        listed[(tax_code, day, band)].append((minutes_of(start), minutes_of(end)))

    return ConfirmedTimes(
        bands={(day, band) for day, band in bands},
        spans={key: merge(spans) for key, spans in listed.items()},
    )


async def teacher_times(db: AsyncSession, start: date, end: date) -> ConfirmedTimes:
    bands = await db.execute(
        select(ConfirmedBand.date, ConfirmedBand.band).where(
            ConfirmedBand.date >= start,
            ConfirmedBand.date < end,
        ),
    )
    hours = await db.execute(
        select(
            ConfirmedHours.teacher_tax_code,
            ConfirmedHours.date,
            ConfirmedHours.band,
            ConfirmedHours.start_time,
            ConfirmedHours.end_time,
        ).where(ConfirmedHours.date >= start, ConfirmedHours.date < end),
    )

    return _times(bands.tuples(), hours.tuples())


async def pupil_times(db: AsyncSession, start: date, end: date) -> ConfirmedTimes:
    bands = await db.execute(
        select(StudentConfirmedBand.date, StudentConfirmedBand.band).where(
            StudentConfirmedBand.date >= start,
            StudentConfirmedBand.date < end,
        ),
    )
    hours = await db.execute(
        select(
            StudentConfirmedHours.student_tax_code,
            StudentConfirmedHours.date,
            StudentConfirmedHours.band,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
        ).where(
            StudentConfirmedHours.date >= start,
            StudentConfirmedHours.date < end,
        ),
    )

    return _times(bands.tuples(), hours.tuples())


# The band of a presence in SQL, as band_of reads its start.
def _presence_band() -> Any:
    return case(
        (Presence.start_time < AFTERNOON_START, TimeBandEnum.MORNING.value),
        (Presence.start_time < EVENING_START, TimeBandEnum.AFTERNOON.value),
        else_=TimeBandEnum.EVENING.value,
    )


# Distinct (student_tax_code, date): bookings where the pupils' band is not
# confirmed, confirmed hours where it is.
def pupil_days_stmt(
    start: date,
    end: date,
    mode: str | None = None,
    tax_codes: Collection[str] | None = None,
) -> CompoundSelect:
    booked = select(Presence.student_tax_code, Presence.date).where(
        Presence.date >= start,
        Presence.date < end,
        ~exists().where(
            StudentConfirmedBand.date == Presence.date,
            StudentConfirmedBand.band == _presence_band(),
        ),
    )
    came = select(
        StudentConfirmedHours.student_tax_code,
        StudentConfirmedHours.date,
    ).where(
        StudentConfirmedHours.date >= start,
        StudentConfirmedHours.date < end,
    )

    if mode is not None:
        booked = booked.where(Presence.mode == mode)
        came = came.where(StudentConfirmedHours.mode == mode)

    if tax_codes is not None:
        booked = booked.where(Presence.student_tax_code.in_(tax_codes))
        came = came.where(StudentConfirmedHours.student_tax_code.in_(tax_codes))

    return union(booked, came)


# One row per lesson and pupil, with the teacher; callers add their filters.
def lesson_rows() -> Select[Any]:
    return (
        select(
            Lesson.id,
            Lesson.date,
            Lesson.band,
            Lesson.start_time,
            Lesson.end_time,
            Availability.teacher_tax_code,
            Presence.student_tax_code,
            Booking.id.label("booking_id"),
            Booking.association_subject_id,
            Booking.service_name,
        )
        .join(Availability, Availability.id == Lesson.availability_id)
        .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
    )


def _span_of(row: Any) -> Span:
    return minutes_of(row.start_time), minutes_of(row.end_time)


# Lesson rows of published bands already over, whole as the calendar has them:
# who taught whom. A lesson goes where its teacher or pupil was absent in a
# confirmed band.
async def done_lessons(
    db: AsyncSession,
    stmt: Select[Any],
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
) -> list[tuple[Any, list[Span]]]:
    rows = (
        await db.execute(stmt.where(Lesson.date >= start, Lesson.date < end))
    ).all()
    published = await published_pairs(db, start, end)
    teachers = await teacher_times(db, start, end)
    pupils = await pupil_times(db, start, end)

    return [
        (row, [_span_of(row)])
        for row in rows
        if (row.date, row.band) in published
        and is_over(row.date, row.end_time)
        and not teachers.absent(row.teacher_tax_code, row.date, row.band)
        and not pupils.absent(row.student_tax_code, row.date, row.band)
    ]


# A person's own lessons of published bands already over, but for the bands
# they were absent in. Per day merged: gaps never count, overlaps once.
async def _own_lessons(
    db: AsyncSession,
    stmt: Select[Any],
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
    confirmed: ConfirmedTimes,
    person: Callable[[Any], str],
) -> TimeByDay:
    rows = (
        await db.execute(stmt.where(Lesson.date >= start, Lesson.date < end))
    ).all()
    published = await published_pairs(db, start, end)
    listed: dict[str, dict[date, list[Span]]] = defaultdict(lambda: defaultdict(list))

    for row in rows:
        if (
            (row.date, row.band) in published
            and is_over(row.date, row.end_time)
            and not confirmed.absent(person(row), row.date, row.band)
        ):
            listed[person(row)][row.date].append(_span_of(row))

    return {
        who: {day: merge(spans) for day, spans in days.items()}
        for who, days in listed.items()
    }


async def teacher_lesson_time(
    db: AsyncSession,
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
    mode: str | None = None,
    tax_codes: Collection[str] | None = None,
) -> TimeByDay:
    stmt = lesson_rows()

    if mode is not None:
        stmt = stmt.where(Lesson.teacher_mode == mode)

    if tax_codes is not None:
        stmt = stmt.where(Availability.teacher_tax_code.in_(tax_codes))

    return await _own_lessons(
        db,
        stmt,
        start,
        end,
        is_over,
        await teacher_times(db, start, end),
        lambda row: row.teacher_tax_code,
    )


async def pupil_lesson_time(
    db: AsyncSession,
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
    mode: str | None = None,
    tax_codes: Collection[str] | None = None,
) -> TimeByDay:
    stmt = lesson_rows()

    if mode is not None:
        stmt = stmt.where(Lesson.mode == mode)

    if tax_codes is not None:
        stmt = stmt.where(Presence.student_tax_code.in_(tax_codes))

    return await _own_lessons(
        db,
        stmt,
        start,
        end,
        is_over,
        await pupil_times(db, start, end),
        lambda row: row.student_tax_code,
    )
