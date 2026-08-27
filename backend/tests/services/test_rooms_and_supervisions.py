from datetime import time

import pytest
from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.room_supervision import RoomSupervision
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.room_supervision import RoomSupervisionCreate
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.room_supervision_service import RoomSupervisionService
from app.services.teacher_room_assignment_service import (
    TeacherRoomAssignmentService,
)
from tests.conftest import ADMIN_IDENTITY
from tests.factories import make_availability, make_room, make_teacher
from tests.services.test_lesson_service import (
    DAY,
    payload,
    scene,
)
from tests.services.test_lesson_service import (
    service as lesson_service,
)


def assignments(db: AsyncSession) -> TeacherRoomAssignmentService:
    return TeacherRoomAssignmentService(
        TeacherRoomAssignmentRepository(db),
        LessonRepository(db),
        RoomRepository(db),
    )


def supervisions(db: AsyncSession) -> RoomSupervisionService:
    return RoomSupervisionService(
        RoomSupervisionRepository(db),
        TeacherRoomAssignmentRepository(db),
    )


async def test_a_convened_teacher_gets_a_room(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))
    room = await make_room(db)

    assignment, warnings = await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    assert assignment.room_id == room.id
    assert warnings == []


# No lessons, no room to be given.
async def test_a_teacher_without_lessons_gets_no_room(db: AsyncSession) -> None:
    teacher = await make_teacher(db)
    await make_availability(db, teacher, day=DAY)
    room = await make_room(db)

    with pytest.raises(HTTPException) as error:
        await assignments(db).assign(
        ADMIN_IDENTITY,
            TeacherRoomAssignmentCreate(
                date=DAY,
                teacher_tax_code=teacher.tax_code,
                room_id=room.id,
            ),
        )

    assert error.value.status_code == 400
    assert "in sede" in error.value.detail


# A remote teacher occupies no room.
async def test_a_teacher_working_from_home_gets_no_room(db: AsyncSession) -> None:
    built = await scene(db, teacher_mode="online", student_mode="online")
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))
    room = await make_room(db)

    with pytest.raises(HTTPException) as error:
        await assignments(db).assign(
        ADMIN_IDENTITY,
            TeacherRoomAssignmentCreate(
                date=DAY,
                teacher_tax_code=built.teacher.tax_code,
                room_id=room.id,
            ),
        )

    assert error.value.status_code == 400


# Over capacity is said and not enforced: the number is optional to begin with.
async def test_a_full_room_is_a_warning(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))
    room = await make_room(db, capacity=1)

    _, warnings = await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    assert len(warnings) == 1
    assert "capienza" in warnings[0]


async def test_a_room_without_a_capacity_never_warns(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))
    room = await make_room(db)

    _, warnings = await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    assert warnings == []


async def _assigned(db: AsyncSession):
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

    return built, room


async def test_a_supervisor_takes_a_shift(db: AsyncSession) -> None:
    built, room = await _assigned(db)

    shift = await supervisions(db).create(
        ADMIN_IDENTITY,
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(14),
            end_time=time(19),
        ),
    )

    assert shift.id is not None


# Refused by the database: a shift's only FK points at the assignment.
async def test_only_an_assigned_teacher_can_watch_a_room(
    db: AsyncSession,
) -> None:
    built, room = await _assigned(db)
    stranger = await make_teacher(db)

    db.add(
        RoomSupervision(
            date=DAY,
            teacher_tax_code=stranger.tax_code,
            room_id=room.id,
            start_time=time(14),
            end_time=time(19),
        ),
    )

    with pytest.raises(IntegrityError):
        await db.flush()


# The shift must fall inside the teacher's offered in-person hours.
async def test_a_shift_outside_the_teachers_hours_is_refused(
    db: AsyncSession,
) -> None:
    built, room = await _assigned(db)

    with pytest.raises(HTTPException) as error:
        await supervisions(db).create(
        ADMIN_IDENTITY,
            RoomSupervisionCreate(
                date=DAY,
                teacher_tax_code=built.teacher.tax_code,
                room_id=room.id,
                start_time=time(9),
                end_time=time(10),
            ),
        )

    assert error.value.status_code == 400
    assert "disponibilità" in error.value.detail


async def test_nobody_watches_two_rooms_at_once(db: AsyncSession) -> None:
    built, room = await _assigned(db)
    other_room = await make_room(db)

    await supervisions(db).create(
        ADMIN_IDENTITY,
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(14),
            end_time=time(17),
        ),
    )

    # The existing shift already covers these hours in the other room.
    with pytest.raises(HTTPException) as error:
        await supervisions(db).create(
        ADMIN_IDENTITY,
            RoomSupervisionCreate(
                date=DAY,
                teacher_tax_code=built.teacher.tax_code,
                room_id=other_room.id,
                start_time=time(15),
                end_time=time(16),
            ),
        )

    assert error.value.status_code == 400


# Removing the assignment removes its shifts, and the count is reported.
async def test_unassigning_takes_the_shifts_along(db: AsyncSession) -> None:
    built, room = await _assigned(db)

    await supervisions(db).create(
        ADMIN_IDENTITY,
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(14),
            end_time=time(19),
        ),
    )

    removed = await assignments(db).unassign(
        ADMIN_IDENTITY,
        DAY,
        built.teacher.tax_code,
    )

    assert removed == 1
    assert await supervisions(db).list_for_day(DAY, room_id=None) == []


# Unused rooms need no supervision.
async def test_unused_rooms_are_simply_unused(db: AsyncSession) -> None:
    built, used = await _assigned(db)
    await make_room(db)
    await make_room(db)

    listed = await assignments(db).list_for_day(DAY)

    assert [assignment.room_id for assignment in listed] == [used.id]
