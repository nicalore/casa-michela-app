from dataclasses import dataclass
from datetime import UTC, date, datetime, time

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.association_subject import AssociationSubject
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.booking_teacher_preference import (
    BookingTeacherPreference,
    TeacherPreferenceTypeEnum,
)
from app.models.calendar_publication import CalendarPublication
from app.models.presence import Presence
from app.models.student import Student
from app.models.teacher import Teacher
from app.repositories.lesson_repository import LessonRepository, LessonVisibility
from app.schemas.lesson import LessonCreate, LessonUpdate
from app.services.lesson_service import LessonService
from tests.conftest import ADMIN_IDENTITY
from tests.factories import (
    make_availability,
    make_booking,
    make_competence,
    make_discipline,
    make_discipline_in_programme,
    make_enrollment,
    make_presence,
    make_student,
    make_study_program,
    make_teacher,
)

DAY = date(2026, 9, 15)

# Opened wide on both sides, so each test states only the hour it cares about.
_OPEN_FROM = time(14)
_OPEN_TO = time(19)

_LESSON_START = time(15)
_LESSON_END = time(16)


@dataclass
class Scene:
    availability: Availability
    booking: Booking
    subject_id: int
    teacher: Teacher
    student: Student
    presence: Presence


@dataclass
class Pupil:
    booking_id: int
    subject_id: int


def service(db: AsyncSession) -> LessonService:
    return LessonService(LessonRepository(db))


def lesson_payload(
    availability: Availability,
    *,
    booking_ids: list[int],
    association_subject_ids: list[int],
    start: time = _LESSON_START,
    end: time = _LESSON_END,
) -> LessonCreate:
    return LessonCreate(
        availability_id=availability.id,
        start_time=start,
        end_time=end,
        booking_ids=booking_ids,
        association_subject_ids=association_subject_ids,
    )


def payload(
    built: Scene,
    *,
    start: time = _LESSON_START,
    end: time = _LESSON_END,
    booking_ids: list[int] | None = None,
    association_subject_ids: list[int] | None = None,
) -> LessonCreate:
    return lesson_payload(
        built.availability,
        booking_ids=booking_ids or [built.booking.id],
        association_subject_ids=association_subject_ids or [built.subject_id],
        start=start,
        end=end,
    )


def pupil_payload(
    availability: Availability,
    pupil: Pupil,
    *,
    start: time = _LESSON_START,
    end: time = _LESSON_END,
) -> LessonCreate:
    return lesson_payload(
        availability,
        booking_ids=[pupil.booking_id],
        association_subject_ids=[pupil.subject_id],
        start=start,
        end=end,
    )


# An offer and a pupil's hours over the same afternoon, on one discipline.
async def _hour_for(
    db: AsyncSession,
    teacher: Teacher,
    student: Student,
    subject: AssociationSubject,
) -> tuple[Availability, Booking]:
    availability = await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
    )
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
    )
    booking = await make_booking(db, presence, association_subject_id=subject.id)

    return availability, booking


# Another pupil the same teacher can take, on a discipline they are competent
# in.
async def _second_pupil_on(
    db: AsyncSession,
    teacher: Teacher,
    *,
    mode: str = "presence",
) -> Pupil:
    subject = await make_discipline(db)
    await make_competence(db, teacher, subject)

    student = await make_student(db)
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
        mode=mode,
    )
    booking = await make_booking(db, presence, association_subject_id=subject.id)

    return Pupil(booking_id=booking.id, subject_id=subject.id)


async def scene(
    db: AsyncSession,
    *,
    teacher_mode: str = "presence",
    student_mode: str = "presence",
    duration: int = 60,
    competent: bool = True,
) -> Scene:
    teacher = await make_teacher(db)
    student = await make_student(db)
    subject = await make_discipline(db)

    if competent:
        await make_competence(db, teacher, subject)

    availability = await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
        mode=teacher_mode,
    )
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
        mode=student_mode,
    )
    booking = await make_booking(
        db,
        presence,
        duration=duration,
        association_subject_id=subject.id,
    )

    return Scene(availability, booking, subject.id, teacher, student, presence)


# The pupil's programme says which grant applies: Matematica for a liceo is not
# Matematica for a technical institute, even though the discipline matches.
async def test_competence_is_read_against_the_pupils_programme(
    db: AsyncSession,
) -> None:
    teacher = await make_teacher(db)
    student = await make_student(db)
    subject = await make_discipline(db)

    taught_programme = await make_study_program(db)
    other_programme = await make_study_program(db)

    await make_competence(db, teacher, subject, taught_programme)
    await make_enrollment(db, student, other_programme)

    # The discipline has to be part of the pupil's programme for the pair to be
    # what decides: one nobody's programme covers is judged on the discipline
    # alone.
    await make_discipline_in_programme(db, subject, other_programme)

    availability, booking = await _hour_for(db, teacher, student, subject)

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            lesson_payload(
                availability,
                booking_ids=[booking.id],
                association_subject_ids=[subject.id],
            ),
        )

    assert error.value.status_code == 400
    assert "competenza" in error.value.detail


async def test_competence_on_the_pupils_own_programme_passes(
    db: AsyncSession,
) -> None:
    teacher = await make_teacher(db)
    student = await make_student(db)
    subject = await make_discipline(db)

    programme = await make_study_program(db)

    await make_competence(db, teacher, subject, programme)
    await make_enrollment(db, student, programme)
    await make_discipline_in_programme(db, subject, programme)

    availability, booking = await _hour_for(db, teacher, student, subject)

    lesson, _ = await service(db).create(
            ADMIN_IDENTITY,
        lesson_payload(
            availability,
            booking_ids=[booking.id],
            association_subject_ids=[subject.id],
        ),
    )

    assert lesson.start_time == _LESSON_START


# A discipline no programme covers has nothing to be compared against, even for
# an enrolled pupil: read on the discipline alone.
async def test_a_discipline_outside_the_programme_ignores_it(
    db: AsyncSession,
) -> None:
    teacher = await make_teacher(db)
    student = await make_student(db)
    subject = await make_discipline(db)

    taught_programme = await make_study_program(db)
    enrolled_programme = await make_study_program(db)

    # Granted for one programme, the pupil is in the other — and the discipline
    # belongs to neither, which is what makes the pair irrelevant here.
    await make_competence(db, teacher, subject, taught_programme)
    await make_enrollment(db, student, enrolled_programme)

    availability, booking = await _hour_for(db, teacher, student, subject)

    lesson, _ = await service(db).create(
            ADMIN_IDENTITY,
        lesson_payload(
            availability,
            booking_ids=[booking.id],
            association_subject_ids=[subject.id],
        ),
    )

    assert lesson.start_time == _LESSON_START


# An adult taking a language has no programme to check against, and refusing
# would make the hour unplannable.
async def test_a_pupil_with_no_school_is_checked_on_the_discipline_alone(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    lesson, _ = await service(db).create(ADMIN_IDENTITY, payload(built))

    assert lesson.start_time == _LESSON_START


# One hour, two programmes: the teacher is in front of both pupils, so both
# competences have to be there.
async def test_a_group_hour_needs_the_competence_on_every_programme(
    db: AsyncSession,
) -> None:
    teacher = await make_teacher(db)
    subject = await make_discipline(db)

    taught = await make_study_program(db)
    other = await make_study_program(db)

    await make_competence(db, teacher, subject, taught)
    await make_discipline_in_programme(db, subject, taught)
    await make_discipline_in_programme(db, subject, other)

    availability = await make_availability(
        db,
        teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
    )

    bookings = []

    for programme in (taught, other):
        student = await make_student(db)
        await make_enrollment(db, student, programme)

        presence = await make_presence(
            db,
            student,
            day=DAY,
            start_time=_OPEN_FROM,
            end_time=_OPEN_TO,
        )
        bookings.append(
            await make_booking(db, presence, association_subject_id=subject.id),
        )

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            lesson_payload(
                availability,
                booking_ids=[booking.id for booking in bookings],
                association_subject_ids=[subject.id],
            ),
        )

    assert error.value.status_code == 400
    assert "competenza" in error.value.detail


async def test_a_lesson_is_created(db: AsyncSession) -> None:
    built = await scene(db)

    lesson, warnings = await service(db).create(ADMIN_IDENTITY, payload(built))

    assert lesson.mode == "presence"
    assert lesson.band == "AFTERNOON"
    assert warnings == []


async def test_a_lesson_must_fit_the_availability(db: AsyncSession) -> None:
    built = await scene(db)

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            payload(built, start=time(13), end=time(14)),
        )

    assert error.value.status_code == 400
    assert "disponibilità" in error.value.detail


async def test_a_lesson_must_fit_the_pupils_hours(db: AsyncSession) -> None:
    built = await scene(db)
    built.presence.start_time = time(16)
    await db.flush()

    with pytest.raises(HTTPException) as error:
        await service(db).create(ADMIN_IDENTITY, payload(built))

    assert error.value.status_code == 400
    assert "ore di" in error.value.detail


# What is capped is the pupils at any one moment, and two is the cap.
async def test_a_teacher_may_take_two_pupils_at_once(db: AsyncSession) -> None:
    built = await scene(db)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    second = await _second_pupil_on(db, built.teacher)

    # The same hour as payload's own, so the two genuinely run together.
    lesson, _ = await service(db).create(
            ADMIN_IDENTITY,
        pupil_payload(built.availability, second),
    )

    assert lesson.start_time == _LESSON_START


# Only hours in the building may run together: a teacher in a call cannot turn
# from it to somebody sitting beside them.
async def test_an_online_hour_may_not_run_alongside_a_hour_in_the_building(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    online_availability = await make_availability(
        db,
        built.teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
        mode="online",
    )

    second = await _second_pupil_on(db, built.teacher, mode="online")

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            pupil_payload(online_availability, second),
        )

    assert error.value.status_code == 400
    assert "online" in error.value.detail


async def test_two_online_hours_may_not_run_together_either(
    db: AsyncSession,
) -> None:
    built = await scene(db, teacher_mode="online", student_mode="online")
    await service(db).create(ADMIN_IDENTITY, payload(built))

    second = await _second_pupil_on(db, built.teacher, mode="online")

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            pupil_payload(built.availability, second),
        )

    assert error.value.status_code == 400
    assert "online" in error.value.detail


# One after the other is fine: what is refused is running together, not the two
# existing on the same afternoon.
async def test_an_online_hour_may_follow_one_in_the_building(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    online_availability = await make_availability(
        db,
        built.teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
        mode="online",
    )

    second = await _second_pupil_on(db, built.teacher, mode="online")

    lesson, _ = await service(db).create(
            ADMIN_IDENTITY,
        pupil_payload(
            online_availability,
            second,
            start=time(16),
            end=time(17),
        ),
    )

    assert lesson.mode == "online"
    assert lesson.teacher_mode == "online"


# Heads and not rows: a group hour of two already fills the teacher up.
async def test_a_teacher_may_not_take_three_pupils_at_once(db: AsyncSession) -> None:
    built = await scene(db)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    second = await _second_pupil_on(db, built.teacher)
    await service(db).create(ADMIN_IDENTITY, pupil_payload(built.availability, second))

    third = await _second_pupil_on(db, built.teacher)

    # Half an hour inside the two that are already there: from half past three
    # to four there would be three of them.
    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            pupil_payload(
                built.availability,
                third,
                start=time(15, 30),
                end=time(16, 30),
            ),
        )

    assert error.value.status_code == 400
    assert "sovrapporre più di 2 lezioni" in error.value.detail


# Touching at an endpoint is not overlapping: three in a row, none at once.
async def test_hours_that_only_touch_do_not_count_as_at_once(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    # Three to four, then two more from four to five: three on the afternoon,
    # never more than two at once.
    for _ in range(2):
        pupil = await _second_pupil_on(db, built.teacher)
        lesson, _ = await service(db).create(
            ADMIN_IDENTITY,
            pupil_payload(
                built.availability,
                pupil,
                start=time(16),
                end=time(17),
            ),
        )

        assert lesson.start_time == time(16)


async def test_a_pupil_cannot_be_in_two_lessons_at_once(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    await service(db).create(ADMIN_IDENTITY, payload(built))

    other_teacher = await make_teacher(db)
    subject = await make_discipline(db)
    await make_competence(db, other_teacher, subject)
    other_availability = await make_availability(
        db,
        other_teacher,
        day=DAY,
        start_time=_OPEN_FROM,
        end_time=_OPEN_TO,
    )
    second_booking = await make_booking(
        db,
        built.presence,
        duration=60,
        association_subject_id=subject.id,
    )

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            lesson_payload(
                other_availability,
                booking_ids=[second_booking.id],
                association_subject_ids=[subject.id],
            ),
        )

    assert error.value.status_code == 400
    assert "studente" in error.value.detail.lower()


async def test_a_teacher_at_home_cannot_take_a_pupil_in_the_building(
    db: AsyncSession,
) -> None:
    built = await scene(db, teacher_mode="online", student_mode="presence")

    with pytest.raises(HTTPException) as error:
        await service(db).create(ADMIN_IDENTITY, payload(built))

    assert error.value.status_code == 400
    assert "da casa" in error.value.detail


async def test_pupils_in_one_lesson_must_share_a_mode(db: AsyncSession) -> None:
    built = await scene(db)
    other = await scene(db, student_mode="online")

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            ADMIN_IDENTITY,
            payload(
                built,
                booking_ids=[built.booking.id, other.booking.id],
                association_subject_ids=[built.subject_id, other.subject_id],
            ),
        )

    assert error.value.status_code == 400
    assert "modalità" in error.value.detail


# Not a preference but a capability, so a refusal rather than a note.
async def test_a_teacher_without_the_competence_is_refused(
    db: AsyncSession,
) -> None:
    built = await scene(db, competent=False)

    with pytest.raises(HTTPException) as error:
        await service(db).create(ADMIN_IDENTITY, payload(built))

    assert error.value.status_code == 400
    assert "competenza" in error.value.detail


# NOT_PREFERRED says who the hour should go to last, not who is forbidden it.
async def test_an_unwanted_teacher_is_a_warning_and_not_a_refusal(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    db.add(
        BookingTeacherPreference(
            booking_id=built.booking.id,
            teacher_tax_code=built.teacher.tax_code,
            preference_type=TeacherPreferenceTypeEnum.NOT_PREFERRED,
        ),
    )
    await db.flush()

    lesson, warnings = await service(db).create(ADMIN_IDENTITY, payload(built))

    assert lesson.id is not None
    assert len(warnings) == 1
    assert "non preferito" in warnings[0]


async def test_a_published_band_is_closed_to_new_lessons(db: AsyncSession) -> None:
    built = await scene(db)

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    with pytest.raises(HTTPException) as error:
        await service(db).create(ADMIN_IDENTITY, payload(built))

    assert error.value.status_code == 409


# The morning going out does not freeze the afternoon.
async def test_another_band_being_published_changes_nothing(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    db.add(CalendarPublication(date=DAY, band="MORNING"))
    await db.flush()

    lesson, _ = await service(db).create(ADMIN_IDENTITY, payload(built))

    assert lesson.band == "AFTERNOON"


async def test_a_stale_write_is_rejected(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    lesson, _ = await service(db).create(ADMIN_IDENTITY, payload(built))

    stale = LessonUpdate(
        availability_id=built.availability.id,
        start_time=_LESSON_START,
        end_time=time(17),
        booking_ids=[built.booking.id],
        association_subject_ids=[built.subject_id],
        expected_updated_at=datetime(2020, 1, 1, tzinfo=UTC),
    )

    with pytest.raises(HTTPException) as error:
        await service(db).update(ADMIN_IDENTITY, lesson.id, stale)

    assert error.value.status_code == 409


async def test_a_lesson_can_be_deleted_while_the_band_is_open(
    db: AsyncSession,
) -> None:
    built = await scene(db)
    lesson, _ = await service(db).create(ADMIN_IDENTITY, payload(built))

    await service(db).delete(ADMIN_IDENTITY, lesson.id)

    remaining = await LessonRepository(db).get_by_id(
        lesson.id,
        visibility=LessonVisibility(),
    )

    assert remaining is None
