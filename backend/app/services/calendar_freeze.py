from collections.abc import Iterable
from datetime import date, datetime, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import now_in_rome
from app.core.i18n import request_language
from app.core.labels import time_band_label
from app.core.time_band import band_of
from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.confirmed_hours import ConfirmedBand
from app.models.lesson import Lesson
from app.models.room_supervision import RoomSupervision
from app.services.bilingual import Bilingual

# The calendar is the plan: what has begun is no longer planned, it happened,
# and its hours are corrected in the daily summary instead.
_STARTED_ERROR: Final[Bilingual] = Bilingual(
    "Non è possibile modificare lezioni già cominciate. È necessario correggere le "
    "ore dal riepilogo giornaliero della Contabilità.",
    "Lessons that have already started cannot be changed. Correct the hours from the "
    "daily summary in Accounting.",
)

_BEGUN_HOURS_ERROR: Final[Bilingual] = Bilingual(
    "Questo orario è già passato.",
    "This time has already passed.",
)

_CONFIRMED_ERROR: Final[Bilingual] = Bilingual(
    "Le ore del {day} ({band}) sono confermate: il calendario di quella fascia non si "
    "può più cambiare.",
    "The hours of {day} ({band}) are confirmed: that time slot's calendar can no "
    "longer change.",
)

# Teacher, start, end and mode of a lesson, activity or shift that has begun.
type StartedRow = tuple[str, str, time, time, str]


def has_started(day: date, start: time | None, now: datetime) -> bool:
    return start is not None and datetime.combine(day, start, tzinfo=now.tzinfo) <= now


def _refuse_started() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=_STARTED_ERROR.for_request(),
    )


def assert_not_started(day: date, *starts: time | None) -> None:
    now = now_in_rome()

    if any(has_started(day, start, now) for start in starts):
        raise _refuse_started()


def has_begun(day: date, start: time) -> bool:
    return has_started(day, start, now_in_rome())


def refuse_begun_hours() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=_BEGUN_HOURS_ERROR.for_request(),
    )


# Bookings and availabilities: an administrator passes a band's close, never its start.
def assert_hours_not_begun(day: date, *starts: time) -> None:
    if any(has_begun(day, start) for start in starts):
        raise refuse_begun_hours()


# A stretch begun keeps its day and start; its end moves only while still ahead.
def assert_only_ahead_moves(
    before: tuple[date, time, time],
    after: tuple[date, time, time],
) -> None:
    if after == before:
        return

    day, start, end = before

    if not has_begun(day, start):
        assert_hours_not_begun(after[0], after[1])

        return

    if after[:2] != (day, start) or has_begun(day, end) or has_begun(day, after[2]):
        raise refuse_begun_hours()


async def assert_not_confirmed(session: AsyncSession, day: date, band: str) -> None:
    confirmed = await session.scalar(
        select(ConfirmedBand.date).where(
            ConfirmedBand.date == day,
            ConfirmedBand.band == band,
        ),
    )

    if confirmed is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_CONFIRMED_ERROR.for_request().format(
                day=day.strftime("%d/%m/%Y"),
                band=time_band_label(band, request_language()).lower(),
            ),
        )


# For writes that drop lessons or activities on the way, booking withdrawn and the like.
async def assert_untouched(
    session: AsyncSession,
    items: Iterable[Lesson | CalendarActivity],
) -> None:
    now = now_in_rome()
    bands: set[tuple[date, str]] = set()

    for item in items:
        if has_started(item.date, item.start_time, now):
            raise _refuse_started()

        bands.add((item.date, item.band))

    for day, band in bands:
        await assert_not_confirmed(session, day, band)


# What of a band has already begun: a write that changes it, however, is refused.
async def started_rows(
    session: AsyncSession,
    day: date,
    band: str,
) -> frozenset[StartedRow]:
    now = now_in_rome()

    lessons = await session.execute(
        select(
            Availability.teacher_tax_code,
            Lesson.start_time,
            Lesson.end_time,
            Lesson.teacher_mode,
        )
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(Lesson.date == day, Lesson.band == band),
    )

    activities = await session.execute(
        select(
            Availability.teacher_tax_code,
            CalendarActivity.start_time,
            CalendarActivity.end_time,
            Availability.mode,
        )
        .join(Availability, Availability.id == CalendarActivity.availability_id)
        .where(CalendarActivity.date == day, CalendarActivity.band == band),
    )

    shifts = await session.execute(
        select(
            RoomSupervision.teacher_tax_code,
            RoomSupervision.start_time,
            RoomSupervision.end_time,
        ).where(RoomSupervision.date == day),
    )

    rows: set[StartedRow] = set()

    for teacher, start, end, mode in lessons.tuples():
        if has_started(day, start, now):
            rows.add(("lesson", teacher, start, end, mode))

    for teacher, start, end, mode in activities.tuples():
        if start is not None and end is not None and has_started(day, start, now):
            rows.add(("activity", teacher, start, end, mode))

    for teacher, start, end in shifts.tuples():
        if str(band_of(start)) == band and has_started(day, start, now):
            rows.add(("shift", teacher, start, end, "presence"))

    return frozenset(rows)


async def assert_started_unchanged(
    session: AsyncSession,
    day: date,
    band: str,
    before: frozenset[StartedRow],
) -> None:
    if await started_rows(session, day, band) != before:
        raise _refuse_started()
