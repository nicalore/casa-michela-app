from datetime import date, time

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import CalendarPublicationCreate
from app.schemas.lesson import LessonCreate
from app.schemas.room_supervision import RoomSupervisionCreate
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.calendar_publication_service import CalendarPublicationService
from app.services.room_supervision_service import RoomSupervisionService
from app.services.teacher_room_assignment_service import (
    TeacherRoomAssignmentService,
)
from tests.conftest import identity_of
from tests.factories import (
    make_administrator,
    make_availability,
    make_competence,
    make_discipline,
    make_ministry_request,
    make_presence,
    make_room,
    make_student,
    make_teacher,
)
from tests.services.test_lesson_service import (
    DAY,
    payload,
    scene,
)
from tests.services.test_lesson_service import (
    service as lesson_service,
)

AFTERNOON = CalendarPublicationCreate(date=DAY, band="AFTERNOON")


def publications(db: AsyncSession) -> CalendarPublicationService:
    return CalendarPublicationService(
        CalendarPublicationRepository(db),
        LessonRepository(db),
        TeacherRoomAssignmentRepository(db),
        RoomSupervisionRepository(db),
        RoomRepository(db),
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


# published_by points at a real administrator, so the identity that publishes
# has to be one: the foreign key is what keeps the record honest about who sent
# the calendar out.
async def admin(db: AsyncSession):
    administrator = await make_administrator(db)

    return identity_of(administrator.tax_code, "ADMIN")


# A whole afternoon in order: one lesson covering its request, the teacher in a
# room, and that room watched from the first minute to the last.
async def _settled_afternoon(db: AsyncSession, *, capacity: int | None = None):
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    room = await make_room(db, capacity=capacity)
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

    return built, room


async def test_a_settled_band_is_published(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    publication, warnings = await publications(db).publish(
        await admin(db),
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"
    assert warnings == []


# Nothing to publish is not a reason to refuse: an empty afternoon is a valid
# afternoon.
async def test_a_band_with_no_lessons_is_published(db: AsyncSession) -> None:
    publication, _ = await publications(db).publish(await admin(db), AFTERNOON)

    assert publication.date == DAY


# Half a request is a state of the work, not a result.
async def test_a_half_covered_request_stops_publication(
    db: AsyncSession,
) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(payload(built, start=time(15), end=time(16)))

    room = await make_room(db)
    await assignments(db).assign(
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(await admin(db), AFTERNOON)

    assert error.value.status_code == 400
    assert "solo in parte" in error.value.detail


# The parts of a request may repeat a discipline, but between them they have to
# cover everything asked for.
async def test_a_discipline_left_untaught_stops_publication(
    db: AsyncSession,
) -> None:
    teacher = await make_teacher(db)
    student = await make_student(db)
    latin = await make_discipline(db)
    greek = await make_discipline(db)

    await make_competence(db, teacher, latin)
    await make_competence(db, teacher, greek)

    availability = await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
    )
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
    )
    booking, _ = await make_ministry_request(db, presence, [latin, greek])

    # The whole two hours, but only one of the two disciplines.
    await lesson_service(db).create(
        LessonCreate(
            availability_id=availability.id,
            start_time=time(15),
            end_time=time(17),
            booking_ids=[booking.id],
            association_subject_ids=[latin.id],
        ),
    )

    room = await make_room(db)
    await assignments(db).assign(
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=teacher.tax_code,
            room_id=room.id,
        ),
    )
    await supervisions(db).create(
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=teacher.tax_code,
            room_id=room.id,
            start_time=time(15),
            end_time=time(17),
        ),
    )

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(await admin(db), AFTERNOON)

    assert error.value.status_code == 400
    assert "non sono assegnate" in error.value.detail


async def test_a_teacher_in_the_building_needs_a_room(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(payload(built))

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(await admin(db), AFTERNOON)

    assert error.value.status_code == 400
    assert "stanza assegnata" in error.value.detail


async def test_a_gap_in_the_cover_stops_publication(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(payload(built, start=time(15), end=time(17)))

    room = await make_room(db)
    await assignments(db).assign(
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    # Covers the first hour only.
    await supervisions(db).create(
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
            start_time=time(15),
            end_time=time(16),
        ),
    )

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(await admin(db), AFTERNOON)

    assert error.value.status_code == 400
    assert "non è presidiata" in error.value.detail


# Capacity is optional, so going over it is said and not enforced.
async def test_an_overfull_room_publishes_with_a_warning(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db, capacity=1)

    publication, warnings = await publications(db).publish(
        await admin(db),
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"
    assert len(warnings) == 1
    assert "capienza" in warnings[0]


async def test_a_room_without_a_capacity_never_warns(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    _, warnings = await publications(db).publish(await admin(db), AFTERNOON)

    assert warnings == []


# Somebody joining from home takes up no chair, so they do not fill the room.
async def test_pupils_at_home_do_not_fill_the_room(db: AsyncSession) -> None:
    built = await scene(db, student_mode="online")
    await lesson_service(db).create(payload(built))

    room = await make_room(db, capacity=1)
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

    _, warnings = await publications(db).publish(await admin(db), AFTERNOON)

    # The teacher alone, and the room holds one.
    assert warnings == []


# Explicit rather than idempotent, so a client learns somebody else published.
async def test_publishing_twice_is_a_conflict(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    identity = await admin(db)

    await publications(db).publish(identity, AFTERNOON)

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(identity, AFTERNOON)

    assert error.value.status_code == 409


# Unpublishing is always allowed: it is the way out of every block.
async def test_a_band_can_be_taken_back_and_published_again(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)
    identity = await admin(db)

    await publications(db).publish(identity, AFTERNOON)
    await publications(db).unpublish(DAY, "AFTERNOON")

    publication, _ = await publications(db).publish(identity, AFTERNOON)

    assert publication.band == "AFTERNOON"


async def test_unpublishing_something_unpublished_is_a_404(
    db: AsyncSession,
) -> None:
    with pytest.raises(HTTPException) as error:
        await publications(db).unpublish(date(2026, 9, 20), "MORNING")

    assert error.value.status_code == 404
