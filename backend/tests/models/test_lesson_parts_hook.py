from datetime import date, time

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from tests.factories import (
    make_availability,
    make_booking,
    make_presence,
    make_student,
    make_teacher,
)

DAY = date(2026, 9, 15)


async def _scene(db: AsyncSession, *, duration: int):
    teacher = await make_teacher(db)
    student = await make_student(db)
    availability = await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=time(6),
        end_time=time(22),
    )
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=time(6),
        end_time=time(22),
    )
    booking = await make_booking(db, presence, duration=duration)

    return availability, booking


def _part(availability, booking, start: time, end: time) -> Lesson:
    return Lesson(
        availability=availability,
        mode="presence",
        start_time=start,
        end_time=end,
        lesson_bookings=[LessonBooking(booking=booking)],
        lesson_disciplines=[
            LessonDiscipline(association_subject_id=booking.association_subject_id),
        ],
    )


async def test_an_hour_may_be_split_in_half(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=60)

    db.add(_part(availability, booking, time(14), time(14, 30)))
    db.add(_part(availability, booking, time(15), time(15, 30)))
    await db.flush()


@pytest.mark.parametrize(
    ("duration", "first", "second"),
    [
        (75, (time(14), time(14, 30)), (time(15), time(15, 45))),
        (105, (time(14), time(15)), (time(15, 15), time(16))),
    ],
)
async def test_uneven_parts_are_allowed(
    db: AsyncSession,
    duration: int,
    first: tuple[time, time],
    second: tuple[time, time],
) -> None:
    availability, booking = await _scene(db, duration=duration)

    db.add(_part(availability, booking, *first))
    db.add(_part(availability, booking, *second))
    await db.flush()


async def test_three_quarters_of_an_hour_cannot_be_split(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=45)

    db.add(_part(availability, booking, time(14), time(14, 30)))
    db.add(_part(availability, booking, time(15), time(15, 30)))

    with pytest.raises(ValueError, match="complessivamente"):
        await db.flush()


async def test_a_third_part_is_refused(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=120)

    db.add(_part(availability, booking, time(14), time(14, 30)))
    db.add(_part(availability, booking, time(15), time(15, 30)))
    db.add(_part(availability, booking, time(16), time(16, 30)))

    with pytest.raises(ValueError, match="al massimo due lezioni"):
        await db.flush()


async def test_the_parts_may_not_outlast_the_request(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=120)

    db.add(_part(availability, booking, time(14), time(15, 30)))
    db.add(_part(availability, booking, time(16), time(17)))

    with pytest.raises(ValueError, match="complessivamente"):
        await db.flush()


async def test_half_a_request_is_a_valid_draft(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=120)

    db.add(_part(availability, booking, time(14), time(15)))
    await db.flush()


async def test_the_two_parts_must_share_a_band(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=60)

    db.add(_part(availability, booking, time(12, 30), time(13)))
    db.add(_part(availability, booking, time(13), time(13, 30)))

    with pytest.raises(ValueError, match="parte della giornata"):
        await db.flush()


async def test_stretching_a_stored_lesson_is_caught(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=120)

    first = _part(availability, booking, time(14), time(15))
    db.add(first)
    db.add(_part(availability, booking, time(16), time(17)))
    await db.flush()

    first.end_time = time(15, 45)

    with pytest.raises(ValueError, match="complessivamente"):
        await db.flush()


async def test_deleting_a_part_is_never_a_problem(db: AsyncSession) -> None:
    availability, booking = await _scene(db, duration=120)

    first = _part(availability, booking, time(14), time(15))
    db.add(first)
    db.add(_part(availability, booking, time(16), time(17)))
    await db.flush()

    await db.delete(first)
    await db.flush()
