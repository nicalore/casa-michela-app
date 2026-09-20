from collections.abc import AsyncIterator
from datetime import time

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext, get_current_identity
from app.db.session import get_db
from app.main import app
from app.models.calendar_publication import CalendarPublication
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.teacher_room_assignment_service import (
    TeacherRoomAssignmentService,
)
from tests.conftest import ADMIN_IDENTITY, identity_of
from tests.factories import make_availability, make_room
from tests.services.test_lesson_service import (
    DAY,
    _second_pupil_on,
    payload,
    pupil_payload,
    scene,
)
from tests.services.test_lesson_service import (
    service as lesson_service,
)

# Visibility is a union of the roles held, not a switch on one.


@pytest_asyncio.fixture
async def client(db: AsyncSession) -> AsyncIterator[AsyncClient]:
    async def _db() -> AsyncIterator[AsyncSession]:
        yield db

    app.dependency_overrides[get_db] = _db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as http:
        yield http

    app.dependency_overrides.clear()


def as_user(identity: IdentityContext) -> None:
    app.dependency_overrides[get_current_identity] = lambda: identity


# Two lessons, two teachers, two pupils: tests check which is seen, not how many.
async def _two_published_lessons(db: AsyncSession):
    first = await scene(db)
    second = await scene(db)

    mine, _ = await lesson_service(db).create(ADMIN_IDENTITY, payload(first))
    theirs, _ = await lesson_service(db).create(ADMIN_IDENTITY,
        payload(second, start=time(17), end=time(18)),
    )

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    return (first, mine.id), (second, theirs.id)


async def _ids(client: AsyncClient) -> set[int]:
    response = await client.get("/lessons/")

    assert response.status_code == 200

    return {row["id"] for row in response.json()}


async def test_an_administrator_sees_everything(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    (_, mine), (_, theirs) = await _two_published_lessons(db)
    as_user(ADMIN_IDENTITY)

    assert await _ids(client) == {mine, theirs}


# Unpublished bands are invisible to everyone but administrators.
async def test_a_draft_is_invisible_to_a_teacher(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    as_user(identity_of(built.teacher.tax_code, "TEACHER"))

    assert await _ids(client) == set()


async def test_an_administrator_sees_the_draft_anyway(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    lesson, _ = await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    as_user(ADMIN_IDENTITY)

    assert await _ids(client) == {lesson.id}


async def test_a_teacher_sees_only_their_own_hours(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    (first, mine), _ = await _two_published_lessons(db)
    as_user(identity_of(first.teacher.tax_code, "TEACHER"))

    assert await _ids(client) == {mine}


async def test_a_pupil_sees_the_lessons_they_are_in(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    (first, mine), _ = await _two_published_lessons(db)
    as_user(identity_of(first.student.tax_code, "STUDENT"))

    assert await _ids(client) == {mine}


async def test_a_parent_sees_their_childs_lessons(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    (first, mine), _ = await _two_published_lessons(db)
    as_user(
        identity_of(
            "PARENT00A01A01X",
            "PARENT",
            children=(first.student.tax_code,),
        ),
    )

    assert await _ids(client) == {mine}


async def test_a_parent_sees_nothing_of_other_families(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    await _two_published_lessons(db)
    as_user(identity_of("PARENT00A01A01X", "PARENT", children=("NOBODY00A01A01X",)))

    assert await _ids(client) == set()


# A teacher-parent sees both, not whichever role was checked first.
async def test_a_teacher_who_is_also_a_parent_sees_the_union(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    (first, mine), (second, theirs) = await _two_published_lessons(db)

    as_user(
        identity_of(
            first.teacher.tax_code,
            "TEACHER",
            "PARENT",
            children=(second.student.tax_code,),
        ),
    )

    # One because they teach it, the other because their child is in it.
    assert await _ids(client) == {mine, theirs}


async def test_a_teacher_cannot_write_the_calendar(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    as_user(identity_of(built.teacher.tax_code, "TEACHER"))

    response = await client.post(
        "/lessons/",
        json={
            "availability_id": built.availability.id,
            "start_time": "15:00:00",
            "end_time": "16:00:00",
            "booking_ids": [built.booking.id],
            "association_subject_ids": [built.subject_id],
        },
    )

    assert response.status_code == 403


async def test_an_administrator_can_write_the_calendar(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    as_user(ADMIN_IDENTITY)

    response = await client.post(
        "/lessons/",
        json={
            "availability_id": built.availability.id,
            "start_time": "15:00:00",
            "end_time": "16:00:00",
            "booking_ids": [built.booking.id],
            "association_subject_ids": [built.subject_id],
        },
    )

    assert response.status_code == 200
    assert response.json()["band"] == "AFTERNOON"


# A pupil learns their teacher's other stretch without seeing the other lesson.
async def test_a_pupil_is_told_of_the_overlap(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    other = await _second_pupil_on(db, built.teacher)

    mine, _ = await lesson_service(db).create(ADMIN_IDENTITY, payload(built))
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        pupil_payload(built.availability, other, start=time(15, 30), end=time(16, 30)),
    )

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    as_user(identity_of(built.student.tax_code, "STUDENT"))

    response = await client.get("/lessons/")

    assert response.status_code == 200

    rows = {row["id"]: row for row in response.json()}

    assert set(rows) == {mine.id}
    assert rows[mine.id]["overlaps"] == [
        {"start_time": "15:30:00", "end_time": "16:00:00"},
    ]


# The room is the day's, for hours in the building; a lesson from home carries none.
async def test_a_lesson_from_home_has_no_room(
    db: AsyncSession,
    client: AsyncClient,
) -> None:
    built = await scene(db)
    in_building, _ = await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    from_home = await make_availability(
        db,
        built.teacher,
        day=DAY,
        start_time=time(16),
        end_time=time(19),
        mode="online",
    )
    other = await _second_pupil_on(db, built.teacher, mode="online")
    at_home, _ = await lesson_service(db).create(
        ADMIN_IDENTITY,
        pupil_payload(from_home, other, start=time(16), end=time(17)),
    )

    room = await make_room(db)

    await TeacherRoomAssignmentService(
        TeacherRoomAssignmentRepository(db),
        LessonRepository(db),
        RoomRepository(db),
    ).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    as_user(ADMIN_IDENTITY)

    response = await client.get("/lessons/")

    assert response.status_code == 200

    rows = {row["id"]: row for row in response.json()}

    assert rows[in_building.id]["room"]["id"] == room.id
    assert rows[at_home.id]["room"] is None
