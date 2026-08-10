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

# Guards shared by everything that can pull the ground out from under a stored
# calendar: the lessons themselves, the availabilities and requests they are
# built on, and the day-closing cleanup. Written once here because the rule is
# one rule, and four copies of it would drift.

_PUBLISHED_BAND_ERROR: Final[str] = (
    "Il calendario del {day} ({band}) è pubblicato: depubblicalo prima di "
    "modificarlo."
)

_ALREADY_SCHEDULED_ERROR: Final[str] = (
    "Questa prenotazione è già stata inserita in una lezione: rimuovi la "
    "lezione prima di modificarla."
)

_AVAILABILITY_SCHEDULED_ERROR: Final[str] = (
    "Ci sono {count} lezioni pianificate su questa disponibilità: rimuovile "
    "prima di procedere."
)


def _day_label(day: date) -> str:
    return day.strftime("%d/%m/%Y")


def published_band_error(day: date, band: str) -> str:
    return _PUBLISHED_BAND_ERROR.format(
        day=_day_label(day),
        band=time_band_label(band).lower(),
    )


async def find_published_bands(
    session: AsyncSession,
    day: date,
) -> set[str]:
    rows = await session.scalars(
        select(CalendarPublication.band).where(CalendarPublication.date == day),
    )

    return set(rows)


# A published band is settled: it has gone out to families and teachers, and the
# way back is to unpublish it, not to edit underneath it.
async def assert_band_not_published(
    session: AsyncSession,
    day: date,
    band: str | TimeBandEnum,
) -> None:
    published = await session.scalar(
        select(CalendarPublication.date).where(
            CalendarPublication.date == day,
            CalendarPublication.band == str(band),
        ),
    )

    if published is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=published_band_error(day, str(band)),
        )


async def assert_bands_not_published(
    session: AsyncSession,
    pairs: Iterable[tuple[date, str | TimeBandEnum]],
) -> None:
    for day, band in dict.fromkeys(pairs):
        await assert_band_not_published(session, day, band)


# Every band of a day that holds a lesson. What the day-closing cleanup has to
# look at before it removes anything, and what an availability's own hours
# answer to.
async def find_bands_with_lessons(
    session: AsyncSession,
    day: date,
) -> set[str]:
    rows = await session.scalars(
        select(Lesson.band).where(Lesson.date == day).distinct(),
    )

    return set(rows)


async def assert_day_has_no_published_lessons(
    session: AsyncSession,
    day: date,
) -> None:
    published = await find_published_bands(session, day)

    if not published:
        return

    with_lessons = await find_bands_with_lessons(session, day)
    clashing = sorted(published & with_lessons)

    if clashing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=published_band_error(day, clashing[0]),
        )


# The bands a single request has been taught in. Narrower than asking about the
# whole day on purpose: the afternoon being published is no reason to freeze a
# request that is only ever taught in the morning.
async def find_booking_bands(
    session: AsyncSession,
    booking_id: int,
) -> set[tuple[date, str]]:
    rows = (
        await session.execute(
            select(Lesson.date, Lesson.band)
            .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
            .where(LessonBooking.booking_id == booking_id),
        )
    ).all()

    return {(day, band) for day, band in rows}


async def assert_booking_band_not_published(
    session: AsyncSession,
    booking_id: int,
) -> None:
    await assert_bands_not_published(
        session,
        await find_booking_bands(session, booking_id),
    )


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


# A request that has been taught cannot be taken back or reshaped: the lesson
# was validated against its duration, its disciplines and its presence, and
# changing any of them now would leave the calendar saying something that was
# never true.
async def assert_bookings_not_scheduled(
    session: AsyncSession,
    booking_ids: Collection[int],
) -> None:
    if await find_scheduled_booking_ids(session, booking_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ALREADY_SCHEDULED_ERROR,
        )


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


async def assert_presence_not_scheduled(
    session: AsyncSession,
    presence_id: int,
) -> None:
    if await find_presence_scheduled_booking_ids(session, presence_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ALREADY_SCHEDULED_ERROR,
        )


async def find_availability_lessons(
    session: AsyncSession,
    availability_id: int,
) -> list[Lesson]:
    rows = await session.scalars(
        select(Lesson).where(Lesson.availability_id == availability_id),
    )

    return list(rows)


# The database would refuse this too, through the RESTRICT on the composite key,
# but with an integrity error and a generic 400. This is here for the sentence.
async def assert_availability_not_scheduled(
    session: AsyncSession,
    availability_id: int,
) -> None:
    lessons = await find_availability_lessons(session, availability_id)

    if lessons:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_AVAILABILITY_SCHEDULED_ERROR.format(count=len(lessons)),
        )
