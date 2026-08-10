from datetime import date, time

import pytest
from sqlalchemy.exc import IntegrityError
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


async def _scene(
    db: AsyncSession,
    *,
    teacher_mode: str = "presence",
    student_mode: str = "presence",
    presence_start: time = time(14),
    presence_end: time = time(19),
):
    teacher = await make_teacher(db)
    student = await make_student(db)
    availability = await make_availability(db, teacher, day=DAY, mode=teacher_mode)
    presence = await make_presence(
        db,
        student,
        day=DAY,
        mode=student_mode,
        start_time=presence_start,
        end_time=presence_end,
    )
    booking = await make_booking(db, presence, duration=120)

    return availability, booking, presence


# The lesson teaches whatever the booking asked for: anything less would trip
# the rule that every pupil in an hour is there for something it covers, which
# is not what these tests are about.
def _lesson(availability, booking, start: time, end: time, *, mode: str = "presence"):
    return Lesson(
        availability=availability,
        mode=mode,
        start_time=start,
        end_time=end,
        lesson_bookings=[LessonBooking(booking=booking)],
        lesson_disciplines=[
            LessonDiscipline(association_subject_id=booking.association_subject_id),
        ],
    )


async def test_a_plain_lesson_is_accepted(db: AsyncSession) -> None:
    availability, booking, presence = await _scene(db)

    db.add(_lesson(availability, booking, time(15), time(16)))
    await db.flush()


@pytest.mark.parametrize(
    ("start", "end"),
    [
        (time(15), time(15, 15)),  # under half an hour
        (time(15, 7), time(16, 7)),  # not on a quarter hour
        (time(16), time(15)),  # ends before it starts
    ],
)
async def test_impossible_hours_are_refused(
    db: AsyncSession,
    start: time,
    end: time,
) -> None:
    availability, booking, presence = await _scene(db)

    db.add(_lesson(availability, booking, start, end))

    with pytest.raises(IntegrityError):
        await db.flush()


# The band is computed by the database, so it cannot disagree with the hours.
@pytest.mark.parametrize(
    ("start", "end", "expected"),
    [
        (time(12), time(13), "MORNING"),
        (time(15), time(16), "AFTERNOON"),
        (time(19), time(20), "EVENING"),
    ],
)
async def test_the_band_follows_the_start_time(
    db: AsyncSession,
    start: time,
    end: time,
    expected: str,
) -> None:
    availability, booking, presence = await _scene(
        db,
        presence_start=time(6),
        presence_end=time(22),
    )
    availability.start_time = time(6)
    availability.end_time = time(22)
    await db.flush()

    lesson = _lesson(availability, booking, start, end)
    db.add(lesson)
    await db.flush()
    await db.refresh(lesson)

    assert lesson.band == expected


# Noon to one is entirely morning; half past twelve to half past one is not
# anything, because a band is the unit the calendar is published in.
async def test_a_lesson_may_not_straddle_two_bands(db: AsyncSession) -> None:
    availability, booking, presence = await _scene(
        db,
        presence_start=time(6),
        presence_end=time(22),
    )
    availability.start_time = time(6)
    availability.end_time = time(22)
    await db.flush()

    db.add(_lesson(availability, booking, time(12, 30), time(13, 30)))

    with pytest.raises(IntegrityError):
        await db.flush()


# The test that justifies the composite foreign key: a lesson cannot claim a day
# its availability does not have.
async def test_a_lesson_cannot_disagree_with_its_availability(
    db: AsyncSession,
) -> None:
    availability, _, _ = await _scene(db)

    # The pupil's hours are on the sixteenth, so is the lesson, and the hook
    # that compares the two is satisfied. The availability is on the fifteenth,
    # and only the composite foreign key can notice.
    other_day = date(2026, 9, 16)
    student = await make_student(db)
    presence = await make_presence(db, student, day=other_day)
    booking = await make_booking(db, presence)

    # Built column by column and not through the relationship, which is the only
    # way to state a day the availability does not have.
    db.add(
        Lesson(
            availability_id=availability.id,
            date=other_day,
            teacher_mode="presence",
            mode="presence",
            start_time=time(15),
            end_time=time(16),
            lesson_bookings=[LessonBooking(booking=booking)],
            lesson_disciplines=[
                LessonDiscipline(
                    association_subject_id=booking.association_subject_id,
                ),
            ],
        ),
    )

    with pytest.raises(IntegrityError):
        await db.flush()


# A teacher at a screen at home cannot have a pupil sitting in front of them.
async def test_a_teacher_at_home_cannot_teach_in_person(db: AsyncSession) -> None:
    availability, booking, presence = await _scene(db, teacher_mode="online")

    db.add(_lesson(availability, booking, time(15), time(16)))

    with pytest.raises(IntegrityError):
        await db.flush()


# The other way round is the whole point of keeping two modes: someone in the
# building teaches whoever is on a screen.
async def test_a_teacher_in_the_building_may_teach_online(db: AsyncSession) -> None:
    availability, booking, presence = await _scene(db, student_mode="online")

    db.add(_lesson(availability, booking, time(15), time(16), mode="online"))
    await db.flush()


async def test_one_availability_cannot_start_two_lessons_at_once(
    db: AsyncSession,
) -> None:
    availability, booking, presence = await _scene(db)
    other = await make_booking(db, presence, duration=60)

    db.add(_lesson(availability, booking, time(15), time(16)))
    await db.flush()

    db.add(_lesson(availability, other, time(15), time(16)))

    with pytest.raises(IntegrityError):
        await db.flush()
