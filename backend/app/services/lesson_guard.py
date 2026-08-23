from collections.abc import Collection, Iterable
from datetime import date
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import time_band_label
from app.core.time_band import TimeBandEnum
from app.models.booking import Booking
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking

_PUBLISHED_BAND_ERROR: Final[str] = (
    "Il calendario del {day} ({band}) è pubblicato: riportalo in bozza prima di "
    "modificarlo."
)


def _day_label(day: date) -> str:
    return day.strftime("%d/%m/%Y")


def published_band_error(day: date, band: str) -> str:
    return _PUBLISHED_BAND_ERROR.format(
        day=_day_label(day),
        band=time_band_label(band).lower(),
    )


async def find_settled_bands(
    session: AsyncSession,
    day: date,
) -> set[str]:
    rows = await session.scalars(
        select(CalendarPublication.band).where(
            CalendarPublication.date == day,
            CalendarPublication.draft_snapshot.is_(None),
        ),
    )

    return set(rows)


async def assert_band_editable(
    session: AsyncSession,
    day: date,
    band: str | TimeBandEnum,
) -> None:
    settled = await session.scalar(
        select(CalendarPublication.date).where(
            CalendarPublication.date == day,
            CalendarPublication.band == str(band),
            CalendarPublication.draft_snapshot.is_(None),
        ),
    )

    if settled is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=published_band_error(day, str(band)),
        )


async def assert_bands_editable(
    session: AsyncSession,
    pairs: Iterable[tuple[date, str | TimeBandEnum]],
) -> None:
    for day, band in dict.fromkeys(pairs):
        await assert_band_editable(session, day, band)


async def find_bands_with_lessons(
    session: AsyncSession,
    day: date,
) -> set[str]:
    rows = await session.scalars(
        select(Lesson.band).where(Lesson.date == day).distinct(),
    )

    return set(rows)


async def assert_day_has_no_settled_lessons(
    session: AsyncSession,
    day: date,
) -> None:
    settled = await find_settled_bands(session, day)

    if not settled:
        return

    with_lessons = await find_bands_with_lessons(session, day)
    clashing = sorted(settled & with_lessons)

    if clashing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=published_band_error(day, clashing[0]),
        )


async def find_booking_lessons(
    session: AsyncSession,
    booking_id: int,
) -> list[Lesson]:
    rows = await session.scalars(
        select(Lesson)
        .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
        .where(LessonBooking.booking_id == booking_id),
    )

    return list(rows)


async def find_scheduled_booking_ids(
    session: AsyncSession,
    booking_ids: Collection[int],
) -> set[int]:
    if not booking_ids:
        return set()

    rows = await session.scalars(
        select(LessonBooking.booking_id).where(
            LessonBooking.booking_id.in_(booking_ids),
        ),
    )

    return set(rows)


async def find_presence_scheduled_booking_ids(
    session: AsyncSession,
    presence_id: int,
) -> set[int]:
    rows = await session.scalars(
        select(LessonBooking.booking_id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .where(Booking.presence_id == presence_id),
    )

    return set(rows)


async def find_presence_lessons(
    session: AsyncSession,
    presence_id: int,
) -> list[Lesson]:
    rows = await session.scalars(
        select(Lesson)
        .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .where(Booking.presence_id == presence_id),
    )

    return list(rows.unique())


async def find_availability_lessons(
    session: AsyncSession,
    availability_id: int,
) -> list[Lesson]:
    rows = await session.scalars(
        select(Lesson).where(Lesson.availability_id == availability_id),
    )

    return list(rows)
