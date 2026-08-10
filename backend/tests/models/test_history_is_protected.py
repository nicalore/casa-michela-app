from datetime import date, time

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.association_subject import AssociationSubject
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from tests.factories import (
    make_availability,
    make_booking,
    make_presence,
    make_room,
    make_student,
    make_teacher,
)

DAY = date(2026, 9, 15)

# The calendar is kept as a record. Everything holding a lesson up restricts
# rather than cascades, so nothing can be pulled out from under it — and these
# are that decision, checked from the bottom.


async def _lesson(db: AsyncSession):
    teacher = await make_teacher(db)
    student = await make_student(db)
    availability = await make_availability(db, teacher, day=DAY)
    presence = await make_presence(db, student, day=DAY)
    booking = await make_booking(db, presence)

    lesson = Lesson(
        availability=availability,
        mode="presence",
        start_time=time(15),
        end_time=time(16),
        lesson_bookings=[LessonBooking(booking=booking)],
        lesson_disciplines=[
            LessonDiscipline(association_subject_id=booking.association_subject_id),
        ],
    )

    db.add(lesson)
    await db.flush()

    return lesson, availability, booking, presence, teacher


async def test_an_availability_with_lessons_cannot_be_deleted(
    db: AsyncSession,
) -> None:
    _, availability, _, _, _ = await _lesson(db)

    await db.delete(availability)

    with pytest.raises(IntegrityError):
        await db.flush()


async def test_a_scheduled_request_cannot_be_deleted(db: AsyncSession) -> None:
    _, _, booking, _, _ = await _lesson(db)

    await db.delete(booking)

    with pytest.raises(IntegrityError):
        await db.flush()


# The restriction travels up a chain that cascades: presences cascade onto their
# bookings, and the booking is the one that cannot go. This is the case that
# gets discovered late.
async def test_deleting_the_presence_underneath_fails_too(
    db: AsyncSession,
) -> None:
    _, _, _, presence, _ = await _lesson(db)

    await db.delete(presence)

    with pytest.raises(IntegrityError):
        await db.flush()


async def test_a_taught_discipline_stays_in_the_catalogue(
    db: AsyncSession,
) -> None:
    _, _, booking, _, _ = await _lesson(db)

    subject = await db.get(AssociationSubject, booking.association_subject_id)
    await db.delete(subject)

    with pytest.raises(IntegrityError):
        await db.flush()


async def test_a_teacher_with_lessons_cannot_be_deleted(db: AsyncSession) -> None:
    _, _, _, _, teacher = await _lesson(db)

    await db.delete(teacher)

    with pytest.raises(IntegrityError):
        await db.flush()


# Moving the availability is refused as well, and by the same key: without
# ON UPDATE the change fails loudly instead of dragging the lesson to a day
# where nothing has been checked.
async def test_an_availability_with_lessons_cannot_move_day(
    db: AsyncSession,
) -> None:
    _, availability, _, _, _ = await _lesson(db)

    availability.date = date(2026, 9, 16)

    with pytest.raises(IntegrityError):
        await db.flush()


# The other direction: what belongs to the lesson goes with it, and what the
# lesson was built on stays.
async def test_deleting_a_lesson_leaves_its_ingredients_alone(
    db: AsyncSession,
) -> None:
    lesson, availability, booking, _, _ = await _lesson(db)

    await db.delete(lesson)
    await db.flush()

    links = (
        await db.execute(
            select(LessonBooking).where(LessonBooking.lesson_id == lesson.id),
        )
    ).all()
    disciplines = (
        await db.execute(
            select(LessonDiscipline).where(LessonDiscipline.lesson_id == lesson.id),
        )
    ).all()

    assert links == []
    assert disciplines == []
    assert await db.get(type(booking), booking.id) is not None
    assert await db.get(type(availability), availability.id) is not None


async def test_a_room_in_use_cannot_be_deleted(db: AsyncSession) -> None:
    from app.models.teacher_room_assignment import TeacherRoomAssignment

    _, _, _, _, teacher = await _lesson(db)
    room = await make_room(db)

    db.add(
        TeacherRoomAssignment(
            date=DAY,
            teacher_tax_code=teacher.tax_code,
            room_id=room.id,
        ),
    )
    await db.flush()

    await db.delete(room)

    with pytest.raises(IntegrityError):
        await db.flush()
