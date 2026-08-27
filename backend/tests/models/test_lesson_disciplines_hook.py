from datetime import date, time

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.service import Service
from tests.factories import (
    make_availability,
    make_booking,
    make_discipline,
    make_presence,
    make_student,
    make_teacher,
)

DAY = date(2026, 9, 15)


async def _availability(db: AsyncSession):
    teacher = await make_teacher(db)

    return await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=time(6),
        end_time=time(22),
    )


async def _booking_for(db: AsyncSession, *, subject_id=None, service=None, duration=60):
    student = await make_student(db)
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=time(6),
        end_time=time(22),
    )

    return await make_booking(
        db,
        presence,
        duration=duration,
        association_subject_id=subject_id,
        service_name=service,
    )


def _lesson(availability, bookings, subject_ids, *, start=time(15), end=time(16)):
    return Lesson(
        availability=availability,
        mode="presence",
        start_time=start,
        end_time=end,
        lesson_bookings=[LessonBooking(booking=booking) for booking in bookings],
        lesson_disciplines=[
            LessonDiscipline(association_subject_id=subject_id)
            for subject_id in subject_ids
        ],
    )


# A shared lesson: each pupil there for their own discipline.
async def test_two_pupils_on_different_disciplines_share_an_hour(
    db: AsyncSession,
) -> None:
    availability = await _availability(db)
    latin = await make_discipline(db, name="Latino di prova")
    greek = await make_discipline(db, name="Greco di prova")

    first = await _booking_for(db, subject_id=latin.id)
    second = await _booking_for(db, subject_id=greek.id)

    db.add(_lesson(availability, [first, second], [latin.id, greek.id]))
    await db.flush()


async def test_a_pupil_with_nothing_in_common_is_refused(db: AsyncSession) -> None:
    availability = await _availability(db)
    latin = await make_discipline(db, name="Latino altro")
    greek = await make_discipline(db, name="Greco altro")

    first = await _booking_for(db, subject_id=latin.id)
    second = await _booking_for(db, subject_id=greek.id)

    db.add(_lesson(availability, [first, second], [latin.id]))

    with pytest.raises(ValueError, match="in comune"):
        await db.flush()


async def test_a_discipline_nobody_asked_for_is_refused(db: AsyncSession) -> None:
    availability = await _availability(db)
    latin = await make_discipline(db, name="Latino terzo")
    physics = await make_discipline(db, name="Fisica terza")

    booking = await _booking_for(db, subject_id=latin.id)

    db.add(_lesson(availability, [booking], [latin.id, physics.id]))

    with pytest.raises(ValueError, match="collegata"):
        await db.flush()


async def test_a_lesson_of_services_carries_no_discipline(db: AsyncSession) -> None:
    availability = await _availability(db)
    service = Service(name=f"Servizio {DAY.isoformat()}")
    db.add(service)
    await db.flush()

    booking = await _booking_for(db, service=service.name)

    db.add(_lesson(availability, [booking], []))
    await db.flush()


async def test_services_and_disciplines_do_not_mix(db: AsyncSession) -> None:
    availability = await _availability(db)
    service = Service(name=f"Servizio misto {DAY.isoformat()}")
    db.add(service)
    await db.flush()

    latin = await make_discipline(db, name="Latino misto")
    taught = await _booking_for(db, subject_id=latin.id)
    served = await _booking_for(db, service=service.name)

    db.add(_lesson(availability, [taught, served], [latin.id]))

    with pytest.raises(ValueError, match="in comune"):
        await db.flush()


# Covering, not partition: parts may repeat a discipline, and a
# single-discipline request is still splittable.
async def test_two_parts_may_repeat_a_discipline(db: AsyncSession) -> None:
    availability = await _availability(db)
    latin = await make_discipline(db, name="Latino diviso")
    booking = await _booking_for(db, subject_id=latin.id, duration=120)

    db.add(_lesson(availability, [booking], [latin.id], start=time(14), end=time(15)))
    db.add(_lesson(availability, [booking], [latin.id], start=time(16), end=time(17)))
    await db.flush()


async def test_a_lesson_needs_at_least_one_booking(db: AsyncSession) -> None:
    availability = await _availability(db)

    db.add(_lesson(availability, [], []))

    with pytest.raises(ValueError, match="almeno una prenotazione"):
        await db.flush()
