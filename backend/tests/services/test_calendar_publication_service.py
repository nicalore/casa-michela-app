from datetime import date, datetime, time, timedelta
from typing import Final
from zoneinfo import ZoneInfo

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.booking_close import assert_still_open, bands_of, closes_at
from app.core.time_band import TimeBandEnum
from app.models.calendar_band_lock import LOCK_TTL_SECONDS, CalendarBandLock
from app.models.lesson import Lesson
from app.repositories.booking_repository import BookingRepository
from app.repositories.calendar_band_lock_repository import (
    CalendarBandLockRepository,
)
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.presence_repository import PresenceRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import CalendarPublicationCreate
from app.schemas.lesson import LessonCreate
from app.schemas.room_supervision import RoomSupervisionCreate
from app.schemas.teacher_room_assignment import TeacherRoomAssignmentCreate
from app.services.booking_service import BookingService
from app.services.calendar_publication_service import CalendarPublicationService
from app.services.room_supervision_service import RoomSupervisionService
from app.services.teacher_room_assignment_service import (
    TeacherRoomAssignmentService,
)
from tests.conftest import ADMIN_IDENTITY, identity_of
from tests.factories import (
    make_administrator,
    make_availability,
    make_booking,
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


_AFTER_CLOSING: Final[datetime] = datetime(2026, 9, 15, 19, tzinfo=ZoneInfo("Europe/Rome"))


def publications(
    db: AsyncSession,
    *,
    now: datetime = _AFTER_CLOSING,
) -> CalendarPublicationService:
    return CalendarPublicationService(
        CalendarPublicationRepository(db),
        LessonRepository(db),
        TeacherRoomAssignmentRepository(db),
        RoomSupervisionRepository(db),
        RoomRepository(db),
        now=lambda: now,
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


async def admin(db: AsyncSession):
    administrator = await make_administrator(db)

    return identity_of(administrator.tax_code, "ADMIN")


# Whoever was building has gone away: the last beat is old enough that the band
# is nobody's again. A bozza, which lives in the database, is still open.
async def _abandon_the_band(db: AsyncSession) -> None:
    await db.execute(
        update(CalendarBandLock).values(
            heartbeat_at=CalendarBandLock.heartbeat_at
            - timedelta(seconds=LOCK_TTL_SECONDS + 1),
        ),
    )
    await db.flush()


async def _settled_afternoon(db: AsyncSession, *, capacity: int | None = None):
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    room = await make_room(db, capacity=capacity)
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

    return built, room


async def test_a_settled_band_is_published(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    publication, warnings = await publications(db).publish(
        ADMIN_IDENTITY,
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"
    assert warnings == []


async def test_a_band_with_no_lessons_is_published(db: AsyncSession) -> None:
    publication, _ = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert publication.date == DAY


async def test_a_half_covered_request_stops_publication(
    db: AsyncSession,
) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(16)),
    )

    room = await make_room(db)
    await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert error.value.status_code == 400
    assert "solo in parte" in error.value.detail


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

    await lesson_service(db).create(ADMIN_IDENTITY,
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
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=teacher.tax_code,
            room_id=room.id,
        ),
    )
    await supervisions(db).create(
        ADMIN_IDENTITY,
        RoomSupervisionCreate(
            date=DAY,
            teacher_tax_code=teacher.tax_code,
            room_id=room.id,
            start_time=time(15),
            end_time=time(17),
        ),
    )

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert error.value.status_code == 400
    assert "non sono assegnate" in error.value.detail


async def test_a_teacher_without_a_room_still_publishes(db: AsyncSession) -> None:
    built = await scene(db)
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    publication, warnings = await publications(db).publish(
        ADMIN_IDENTITY,
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"
    assert warnings == []


async def test_a_gap_in_the_cover_still_publishes(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(17)),
    )

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

    publication, _ = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert publication.band == "AFTERNOON"


async def test_an_empty_hour_between_two_lessons_is_not_a_gap(
    db: AsyncSession,
) -> None:
    built = await scene(db, duration=120)
    room = await make_room(db)

    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(16)),
    )
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(17), end=time(18)),
    )

    await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    for start, end in ((time(15), time(16)), (time(17), time(18))):
        await supervisions(db).create(
        ADMIN_IDENTITY,
            RoomSupervisionCreate(
                date=DAY,
                teacher_tax_code=built.teacher.tax_code,
                room_id=room.id,
                start_time=start,
                end_time=end,
            ),
        )

    publication, _ = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert publication.band == "AFTERNOON"


async def test_an_overfull_room_publishes_with_a_warning(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db, capacity=1)

    publication, warnings = await publications(db).publish(
        ADMIN_IDENTITY,
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"
    assert len(warnings) == 1
    assert "capienza" in warnings[0]


async def test_a_room_without_a_capacity_never_warns(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    _, warnings = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert warnings == []


async def test_pupils_at_home_do_not_fill_the_room(db: AsyncSession) -> None:
    built = await scene(db, student_mode="online")
    await lesson_service(db).create(ADMIN_IDENTITY, payload(built))

    room = await make_room(db, capacity=1)
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

    _, warnings = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert warnings == []


_ROME = ZoneInfo("Europe/Rome")


async def test_the_afternoon_cannot_go_out_before_eleven(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    early = datetime(2026, 9, 15, 10, 59, tzinfo=_ROME)

    with pytest.raises(ValueError, match="si può pubblicare"):
        await publications(db, now=early).publish(ADMIN_IDENTITY, AFTERNOON)


async def test_the_afternoon_goes_out_from_eleven(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    on_the_hour = datetime(2026, 9, 15, 11, 0, tzinfo=_ROME)
    publication, _ = await publications(db, now=on_the_hour).publish(
        ADMIN_IDENTITY,
        AFTERNOON,
    )

    assert publication.band == "AFTERNOON"


def test_each_part_of_the_day_closes_at_its_own_hour() -> None:
    day = date(2026, 9, 15)

    assert closes_at(day, TimeBandEnum.MORNING) == datetime(
        2026, 9, 14, 20, tzinfo=_ROME,
    )
    assert closes_at(day, TimeBandEnum.AFTERNOON) == datetime(
        2026, 9, 15, 11, tzinfo=_ROME,
    )
    assert closes_at(day, TimeBandEnum.EVENING) == datetime(
        2026, 9, 15, 18, tzinfo=_ROME,
    )


def test_a_stretch_over_a_boundary_belongs_to_both_parts_of_the_day() -> None:
    assert bands_of(time(14), time(20)) == {
        TimeBandEnum.AFTERNOON,
        TimeBandEnum.EVENING,
    }
    assert bands_of(time(14), time(18)) == {TimeBandEnum.AFTERNOON}


def test_a_family_is_shut_out_at_the_hour_and_an_administrator_is_not() -> None:
    day = date(2026, 9, 15)
    afternoon = [TimeBandEnum.AFTERNOON]
    past_it = datetime(2026, 9, 15, 11, tzinfo=_ROME)

    with pytest.raises(ValueError, match="solo un amministratore"):
        assert_still_open(day, afternoon, is_admin=False, now=past_it)

    assert_still_open(day, afternoon, is_admin=True, now=past_it)
    assert_still_open(
        day,
        afternoon,
        is_admin=False,
        now=datetime(2026, 9, 15, 10, 59, tzinfo=_ROME),
    )


async def test_a_reopened_band_is_still_published(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    publication = await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert publication.draft_snapshot is not None
    assert await publications(db).repository.is_published(DAY, "AFTERNOON")


async def test_a_band_that_never_went_out_cannot_be_reopened(
    db: AsyncSession,
) -> None:
    with pytest.raises(HTTPException) as error:
        await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert error.value.status_code == 404


async def test_reopening_twice_is_a_conflict(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    with pytest.raises(HTTPException) as error:
        await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert error.value.status_code == 409


async def test_closing_an_untouched_draft_sends_nothing(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    published, _ = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    went_out = published.published_at

    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")
    publication, _, resent = await publications(db).settle(
        ADMIN_IDENTITY,
        DAY,
        "AFTERNOON",
    )

    assert resent is False
    assert publication.draft_snapshot is None
    assert publication.published_at == went_out


async def test_closing_a_changed_draft_sends_it_again(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    # The bozza is a sitting of its own, and whoever opens it is who closes it:
    # publishing let the band go, so somebody else can pick it up.
    closer = await admin(db)
    await publications(db).reopen(closer, DAY, "AFTERNOON")

    lesson = (await db.execute(select(Lesson))).scalars().one()
    lesson.start_time = time(16)
    lesson.end_time = time(17)
    await db.flush()

    publication, _, resent = await publications(db).settle(closer, DAY, "AFTERNOON")

    assert resent is True
    assert publication.published_by == closer.tax_code
    assert closer.tax_code != ADMIN_IDENTITY.tax_code


async def test_moving_an_hour_and_moving_it_back_sends_nothing(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    lesson = (await db.execute(select(Lesson))).scalars().one()
    was = (lesson.start_time, lesson.end_time)
    lesson.start_time, lesson.end_time = time(16), time(17)
    await db.flush()
    lesson.start_time, lesson.end_time = was
    await db.flush()

    _, _, resent = await publications(db).settle(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert resent is False


# Leaving the bozza without publishing puts the part of the day back as it was
# when it was opened. It is what the whole picture is kept for.
async def test_leaving_a_bozza_undoes_the_work_in_it(db: AsyncSession) -> None:
    built = await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    lesson = (await db.execute(select(Lesson))).scalars().one()
    lesson.start_time = time(16)
    lesson.end_time = time(17)
    await db.flush()

    lost = await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert lost == 0

    # The bookings asked for by name: read off a lesson that happens to be in
    # the session already they come for free, and off one that is not they are
    # a query from inside a sync attribute access, which is a greenlet error
    # rather than a failed assertion.
    back = (
        await db.execute(
            select(Lesson).options(selectinload(Lesson.lesson_bookings)),
        )
    ).scalars().one()

    assert (back.start_time, back.end_time) == (time(15), time(16))
    assert back.lesson_bookings[0].booking_id == built[0].booking.id


async def test_leaving_a_bozza_closes_it(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")
    await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    publication = await publications(db).repository.get(DAY, "AFTERNOON")

    assert publication is not None
    assert publication.draft_snapshot is None
    # Still published, and never sent again: nothing changed in the end.
    assert publication.published_at is not None


# An hour added in the bozza was never part of what went out, so it goes.
async def test_leaving_a_bozza_takes_away_what_was_added_in_it(
    db: AsyncSession,
) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(16)),
    )

    room = await make_room(db)
    await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(16), end=time(17)),
    )
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    only = (await db.execute(select(Lesson).order_by(Lesson.start_time))).scalars().first()
    await lesson_service(db).delete(ADMIN_IDENTITY, only.id)

    assert await db.scalar(select(func.count()).select_from(Lesson)) == 1

    await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert await db.scalar(select(func.count()).select_from(Lesson)) == 2


# What cannot come back: the request the hour was teaching is gone, so the hour
# it was checked against is not a calendar the database would accept any more.
async def test_an_hour_whose_request_went_cannot_be_put_back(
    db: AsyncSession,
) -> None:
    built = await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    await BookingService(BookingRepository(db), PresenceRepository(db)).delete(
        ADMIN_IDENTITY,
        built[0].booking.id,
    )

    lost = await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert lost == 1
    assert await db.scalar(select(func.count()).select_from(Lesson)) == 0


async def test_leaving_a_bozza_nobody_opened_is_a_conflict(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    with pytest.raises(HTTPException) as error:
        await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert error.value.status_code == 409


async def test_closing_a_draft_nobody_opened_is_a_conflict(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    with pytest.raises(HTTPException) as error:
        await publications(db).settle(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert error.value.status_code == 409


async def test_a_settled_band_refuses_lesson_writes(db: AsyncSession) -> None:
    built, _ = await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    with pytest.raises(HTTPException) as error:
        await lesson_service(db).create(
            ADMIN_IDENTITY,
            payload(built, start=time(17), end=time(18)),
        )

    assert error.value.status_code == 409
    assert "in bozza" in error.value.detail


async def test_a_reopened_band_takes_lesson_writes_again(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(15), end=time(16)),
    )

    room = await make_room(db)
    await assignments(db).assign(
        ADMIN_IDENTITY,
        TeacherRoomAssignmentCreate(
            date=DAY,
            teacher_tax_code=built.teacher.tax_code,
            room_id=room.id,
        ),
    )
    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(built, start=time(16), end=time(17)),
    )
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    lesson = (
        await db.execute(select(Lesson).order_by(Lesson.start_time))
    ).scalars().first()

    with pytest.raises(HTTPException) as error:
        await lesson_service(db).delete(ADMIN_IDENTITY, lesson.id)

    assert error.value.status_code == 409

    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")
    await lesson_service(db).delete(ADMIN_IDENTITY, lesson.id)

    assert await db.scalar(select(func.count()).select_from(Lesson)) == 1


async def test_a_cascade_on_a_settled_band_reopens_it(db: AsyncSession) -> None:
    built, _ = await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    await BookingService(BookingRepository(db), PresenceRepository(db)).delete(
        ADMIN_IDENTITY,
        built.booking.id,
    )

    publication = await publications(db).repository.get(DAY, "AFTERNOON")

    assert publication is not None
    assert publication.draft_snapshot is not None


async def test_publishing_twice_is_a_conflict(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    identity = ADMIN_IDENTITY

    await publications(db).publish(identity, AFTERNOON)

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(identity, AFTERNOON)

    assert error.value.status_code == 409


async def test_a_band_can_be_taken_back_and_published_again(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)
    identity = ADMIN_IDENTITY

    await publications(db).publish(identity, AFTERNOON)
    await publications(db).unpublish(ADMIN_IDENTITY, DAY, "AFTERNOON")

    publication, _ = await publications(db).publish(identity, AFTERNOON)

    assert publication.band == "AFTERNOON"


async def test_unpublishing_something_unpublished_is_a_404(
    db: AsyncSession,
) -> None:
    with pytest.raises(HTTPException) as error:
        await publications(db).unpublish(ADMIN_IDENTITY, date(2026, 9, 20), "MORNING")

    assert error.value.status_code == 404


# A request that arrived after the calendar was built, and that nobody ever put
# anywhere. Everything above reads requests through the lessons that teach them,
# so until this one was added it was the one thing checked nowhere.


async def _an_unplanned_request(db: AsyncSession, *, start: time, end: time):
    student = await make_student(db)
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=start,
        end_time=end,
    )

    return await make_booking(db, presence)


async def test_a_request_nobody_planned_stops_publication(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await _an_unplanned_request(db, start=time(14), end=time(19))

    with pytest.raises(HTTPException) as error:
        await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert error.value.status_code == 400
    assert "non sono state pianificate" in error.value.detail


async def test_a_request_nobody_planned_stops_closing_a_bozza(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    await _an_unplanned_request(db, start=time(14), end=time(19))

    with pytest.raises(HTTPException) as error:
        await publications(db).settle(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert error.value.status_code == 400


# The one that says "planned nowhere" and not "planned in this band": a pupil
# staying from noon has the one request, and having taught it in the morning is
# no reason to hold up the afternoon.
async def test_a_request_taught_in_the_other_half_of_the_day_does_not(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)

    straddling = await scene(db)
    straddling.presence.start_time = time(11)
    straddling.availability.start_time = time(11)
    await db.flush()

    await lesson_service(db).create(
        ADMIN_IDENTITY,
        payload(straddling, start=time(11), end=time(12)),
    )

    publication, _ = await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert publication.band == "AFTERNOON"


# Leaving a bozza puts the band back as it was when it opened, so it is the
# opener's to leave and nobody else's.


async def test_leaving_a_bozza_is_only_the_openers(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    # The opener walked away and the band came free, which is exactly the case
    # the lock cannot cover: a bozza outlives it many times over.
    await _abandon_the_band(db)

    other = await admin(db)

    with pytest.raises(HTTPException) as error:
        await publications(db).discard(other, DAY, "AFTERNOON")

    assert error.value.status_code == 409
    assert "La bozza è stata aperta da" in error.value.detail


async def test_a_bozza_with_nobody_s_name_on_it_can_still_be_left(
    db: AsyncSession,
) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    # A bozza opened before any of this existed, as the migration leaves them.
    publication = await CalendarPublicationRepository(db).get(DAY, "AFTERNOON")
    publication.draft_opened_by = None
    await db.flush()
    await _abandon_the_band(db)

    await publications(db).discard(await admin(db), DAY, "AFTERNOON")

    assert publication.draft_snapshot is None


# The sitting ends when the band goes out or the bozza closes, and the band goes
# back to everybody: holding it any longer would only keep the next person out.


async def _held_by(db: AsyncSession) -> str | None:
    lock = await CalendarBandLockRepository(db).holder(DAY, "AFTERNOON")

    return lock.holder_tax_code if lock is not None else None


async def test_publishing_lets_the_band_go(db: AsyncSession) -> None:
    await _settled_afternoon(db)

    assert await _held_by(db) == ADMIN_IDENTITY.tax_code

    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)

    assert await _held_by(db) is None


async def test_closing_a_bozza_lets_the_band_go(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert await _held_by(db) == ADMIN_IDENTITY.tax_code

    await publications(db).settle(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert await _held_by(db) is None


async def test_leaving_a_bozza_lets_the_band_go(db: AsyncSession) -> None:
    await _settled_afternoon(db)
    await publications(db).publish(ADMIN_IDENTITY, AFTERNOON)
    await publications(db).reopen(ADMIN_IDENTITY, DAY, "AFTERNOON")

    await publications(db).discard(ADMIN_IDENTITY, DAY, "AFTERNOON")

    assert await _held_by(db) is None
