from datetime import time

import pytest
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.availability_repository import AvailabilityRepository
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.booking import BookingUpdate
from app.schemas.presence import PresenceUpdate
from app.schemas.room_supervision import RoomSupervisionCreate
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.availability_cleanup import purge_availabilities_for_closed_days
from app.services.availability_service import AvailabilityService
from app.services.booking_service import BookingService
from app.services.presence_service import PresenceService
from tests.conftest import ADMIN_IDENTITY
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


async def _count(db: AsyncSession, model) -> int:
    return len((await db.execute(select(model))).scalars().all())


async def _afternoon_with_a_room(db: AsyncSession):
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    room = await make_room(db)
    await assignments(db).assign(
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    await supervisions(db).create(
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(15),
            end_time=time(16),
        ),
    )

    return built


# Closing the day would take a published calendar away without anybody being
# told, so it is refused and everything stays where it is.
async def test_closing_a_published_day_is_refused(db: AsyncSession) -> None:
    await _afternoon_with_a_room(db)

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    with pytest.raises(ValueError, match="depubblica"):
        await purge_availabilities_for_closed_days(db, [DAY], "presence")

    assert await _count(db, Lesson) == 1
    assert await _count(db, TeacherRoomAssignment) == 1
    assert await _count(db, RoomSupervision) == 1


# A draft is work in progress and not history: it goes, and so do the room and
# the shifts, which hang off neither the availabilities nor the presences and
# would otherwise be left against a closed day.
async def test_closing_a_day_of_drafts_clears_everything(
    db: AsyncSession,
) -> None:
    await _afternoon_with_a_room(db)

    await purge_availabilities_for_closed_days(db, [DAY], "presence")

    assert await _count(db, Lesson) == 0
    assert await _count(db, TeacherRoomAssignment) == 0
    assert await _count(db, RoomSupervision) == 0


def _booking_update(built, **overrides) -> BookingUpdate:
    fields = {
        "duration": built.booking.duration,
        "association_subject_id": built.subject_id,
        # A request has to say what kind of hour it is.
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


# Adding a note to an hour already on the timetable is exactly when somebody
# wants to, so the harmless fields stay open.
async def test_a_note_can_still_be_added_to_a_scheduled_request(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    updated = await _bookings(db).update(
        ADMIN_IDENTITY,
        built.booking.id,
        _booking_update(built, topic="Ripasso"),
    )

    assert updated.topic == "Ripasso"


# The length is what the lesson was checked against, so it can no longer move.
async def test_a_scheduled_request_cannot_change_length(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    with pytest.raises(HTTPException) as error:
        await _bookings(db).update(
            ADMIN_IDENTITY,
            built.booking.id,
            _booking_update(built, duration=90),
        )

    assert error.value.status_code == 400
    assert "già in una lezione" in error.value.detail


async def test_a_scheduled_request_cannot_be_deleted(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    with pytest.raises(HTTPException) as error:
        await _bookings(db).delete(ADMIN_IDENTITY, built.booking.id)

    assert error.value.status_code == 400


# Narrowing the pupil's hours would leave the lesson outside them.
async def test_a_scheduled_presence_cannot_be_narrowed(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    service = PresenceService(PresenceRepository(db))

    with pytest.raises(HTTPException) as error:
        await service.update(
            ADMIN_IDENTITY,
            built.presence.id,
            PresenceUpdate(
                date=DAY,
                mode="presence",
                start_time=time(17),
                end_time=time(19),
            ),
        )

    assert error.value.status_code == 400


async def test_a_scheduled_presence_cannot_be_deleted(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    service = PresenceService(PresenceRepository(db))

    with pytest.raises(HTTPException) as error:
        await service.delete(ADMIN_IDENTITY, built.presence.id)

    assert error.value.status_code == 400


# Refused for everybody, administrators included: there is no cascade left to
# authorise, and the way through is to remove the lessons first.
async def test_an_availability_with_lessons_is_not_deletable_by_an_admin(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    service = AvailabilityService(AvailabilityRepository(db))

    with pytest.raises(HTTPException) as error:
        await service.delete(ADMIN_IDENTITY, built.availability.id)

    assert error.value.status_code == 400
    assert "lezioni pianificate" in error.value.detail
