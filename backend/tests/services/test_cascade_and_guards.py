from contextlib import contextmanager
from datetime import datetime, time
from unittest.mock import patch
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.opening_day import OpeningDay
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.availability_repository import AvailabilityRepository
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.availability import AvailabilityUpdate
from app.schemas.booking import BookingUpdate
from app.schemas.room_supervision import RoomSupervisionCreate
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.availability_cleanup import purge_hours_outside_openings
from app.services.availability_service import AvailabilityService
from app.services.booking_service import BookingService
from app.services.presence_service import PresenceService
from tests.conftest import ADMIN_IDENTITY, identity_of
from tests.factories import make_room
from tests.services.test_calendar_publication_service import (
    assignments,
    supervisions,
)
from tests.services.test_lesson_service import (
    DAY,
    payload,
    scene,
)
from tests.services.test_lesson_service import (
    service as lesson_service,
)

_ROME = ZoneInfo("Europe/Rome")


@contextmanager
def freeze(moment: datetime):
    with patch("app.core.booking_close.now_in_rome", return_value=moment):
        yield


async def _count(db: AsyncSession, model) -> int:
    return len((await db.execute(select(model))).scalars().all())


async def _afternoon_with_a_room(db: AsyncSession):
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    room = await make_room(db)
    await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    await supervisions(db).create(
        ADMIN_IDENTITY,
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(15),
            end_time=time(16),
        ),
    )

    return built


# A closed day deletes everything on it, published included; the
# publication row goes via calendar_hours_sync.
async def test_closing_a_published_day_clears_it_too(db: AsyncSession) -> None:
    await _afternoon_with_a_room(db)

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    await purge_hours_outside_openings(db, [DAY], "presence")

    assert await _count(db, Lesson) == 0
    assert await _count(db, TeacherRoomAssignment) == 0
    assert await _count(db, RoomSupervision) == 0


async def test_closing_a_day_of_drafts_clears_everything(
    db: AsyncSession,
) -> None:
    await _afternoon_with_a_room(db)

    await purge_hours_outside_openings(db, [DAY], "presence")

    assert await _count(db, Lesson) == 0
    assert await _count(db, TeacherRoomAssignment) == 0
    assert await _count(db, RoomSupervision) == 0


def _booking_update(built, **overrides) -> BookingUpdate:
    fields = {
        "duration": built.booking.duration,
        "association_subject_id": built.subject_id,
        "tags": ["HOMEWORK"],
        "topic": None,
        "notes": None,
        "preferred_teacher_tax_codes": [],
        "not_preferred_teacher_tax_codes": [],
    }
    fields.update(overrides)

    return BookingUpdate(**fields)


def _bookings(db: AsyncSession) -> BookingService:
    return BookingService(BookingRepository(db), PresenceRepository(db))


async def test_a_teacher_cannot_withdraw_hours_once_the_bookings_close(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    service = AvailabilityService(AvailabilityRepository(db))
    teacher = identity_of(built.teacher.tax_code, "TEACHER")

    with freeze(datetime(2026, 9, 15, 11, tzinfo=_ROME)):
        with pytest.raises(ValueError, match="solo un amministratore"):
            await service.delete(teacher, built.availability.id)


async def test_a_teacher_can_withdraw_them_before_they_close(db: AsyncSession) -> None:
    built = await scene(db)

    service = AvailabilityService(AvailabilityRepository(db))
    teacher = identity_of(built.teacher.tax_code, "TEACHER")

    with freeze(datetime(2026, 9, 15, 10, 59, tzinfo=_ROME)):
        await service.delete(teacher, built.availability.id)

    assert await _count(db, Lesson) == 0


async def test_an_administrator_is_not_held_to_the_closing(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    service = AvailabilityService(AvailabilityRepository(db))

    with freeze(datetime(2026, 9, 15, 23, tzinfo=_ROME)):
        await service.delete(ADMIN_IDENTITY, built.availability.id)

    assert await _count(db, Lesson) == 0


async def test_a_family_cannot_withdraw_a_request_once_the_bookings_close(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    student = identity_of(built.student.tax_code, "STUDENT")

    with freeze(datetime(2026, 9, 15, 11, tzinfo=_ROME)):
        with pytest.raises(ValueError, match="solo un amministratore"):
            await _bookings(db).delete(student, built.booking.id)


async def test_a_note_can_still_be_added_to_a_scheduled_request(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    updated = await _bookings(db).update(
        ADMIN_IDENTITY,
        built.booking.id,
        _booking_update(built, topic="Ripasso"),
    )

    assert updated.topic == "Ripasso"


async def test_changing_the_length_takes_the_hour_off_the_timetable(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    updated = await _bookings(db).update(
        ADMIN_IDENTITY,
        built.booking.id,
        _booking_update(built, duration=90),
    )

    assert updated.duration == 90
    assert await _count(db, Lesson) == 0


async def test_deleting_a_request_takes_its_hours_with_it(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    await _bookings(db).delete(ADMIN_IDENTITY, built.booking.id)

    assert await _count(db, Lesson) == 0


async def test_narrowing_an_availability_drops_only_what_falls_outside(
    db: AsyncSession,
) -> None:
    built = await scene(db, duration=120)

    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(16)),
    )
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(17), end=time(18)),
    )

    db.add(
        OpeningDay(
            date=DAY,
            mode="presence",
            start_time=time(14),
            end_time=time(19),
            is_override=False,
        ),
    )
    await db.flush()

    service = AvailabilityService(AvailabilityRepository(db))

    await service.update(
        ADMIN_IDENTITY,
        built.availability.id,
        AvailabilityUpdate(
            date=DAY,
            mode="presence",
            start_time=time(15),
            end_time=time(16, 30),
        ),
    )

    remaining = (await db.execute(select(Lesson))).scalars().all()

    assert [lesson.start_time for lesson in remaining] == [time(15)]


async def test_deleting_a_presence_takes_its_hours_with_it(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    service = PresenceService(PresenceRepository(db))

    await service.delete(ADMIN_IDENTITY, built.presence.id)

    assert await _count(db, Lesson) == 0


async def test_deleting_an_availability_takes_its_lessons_with_it(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    service = AvailabilityService(AvailabilityRepository(db))

    await service.delete(ADMIN_IDENTITY, built.availability.id)

    assert await _count(db, Lesson) == 0
