from dataclasses import dataclass
from datetime import UTC, date, datetime, time

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking_teacher_preference import (
    BookingTeacherPreference,
    TeacherPreferenceTypeEnum,
)
from app.models.calendar_publication import CalendarPublication
from app.repositories.lesson_repository import LessonRepository, LessonVisibility
from app.schemas.lesson import LessonCreate, LessonUpdate
from app.services.lesson_service import LessonService
from tests.conftest import ADMIN_IDENTITY
from tests.factories import (
    make_availability,
    make_booking,
    make_competence,
    make_discipline,
    make_presence,
    make_student,
    make_teacher,
)

DAY = date(2026, 9, 15)


@dataclass
class Scene:
    availability: object
    booking: object
    subject_id: int
    teacher: object
    student: object
    presence: object


def service(db: AsyncSession) -> LessonService:
    return LessonService(LessonRepository(db))


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
        start_time=time(14),
        end_time=time(19),
        mode=teacher_mode,
    )
    presence = await make_presence(
        db,
        student,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
        mode=student_mode,
    )
    booking = await make_booking(
        db,
        presence,
        duration=duration,
        association_subject_id=subject.id,
    )

    return Scene(availability, booking, subject.id, teacher, student, presence)


def payload(scene: Scene, *, start=time(15), end=time(16), **overrides) -> LessonCreate:
    return LessonCreate(
        availability_id=overrides.get("availability_id", scene.availability.id),
        start_time=start,
        end_time=end,
        booking_ids=overrides.get("booking_ids", [scene.booking.id]),
        association_subject_ids=overrides.get(
            "association_subject_ids",
            [scene.subject_id],
        ),
    )


async def test_a_lesson_is_created(db: AsyncSession) -> None:
    built = await scene(db)

    lesson, warnings = await service(db).create(payload(built))

    assert lesson.mode == "presence"
    assert lesson.band == "AFTERNOON"
    assert warnings == []


async def test_a_lesson_must_fit_the_availability(db: AsyncSession) -> None:
    built = await scene(db)

    with pytest.raises(HTTPException) as error:
        await service(db).create(payload(built, start=time(13), end=time(14)))

    assert error.value.status_code == 400
    assert "disponibilità" in error.value.detail


async def test_a_lesson_must_fit_the_pupils_hours(db: AsyncSession) -> None:
    built = await scene(db)
    built.presence.start_time = time(16)
    await db.flush()

    with pytest.raises(HTTPException) as error:
        await service(db).create(payload(built, start=time(15), end=time(16)))

    assert error.value.status_code == 400
    assert "ore di" in error.value.detail


# The availabilities allow this and the lessons must not: a teacher cannot be in
# the building for one group and online for another at the same hour.
async def test_a_teacher_cannot_teach_two_groups_at_once(db: AsyncSession) -> None:
    built = await scene(db)
    await service(db).create(payload(built))

    # The same teacher, offering the same hours online as well — which the
    # availabilities allow, since they are kept apart by mode. The lesson is
    # what may not overlap.
    online_availability = await make_availability(
        db,
        built.teacher,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
        mode="online",
    )

    subject = await make_discipline(db)
    await make_competence(db, built.teacher, subject)

    remote_student = await make_student(db)
    remote_presence = await make_presence(
        db,
        remote_student,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
        mode="online",
    )
    remote_booking = await make_booking(
        db,
        remote_presence,
        association_subject_id=subject.id,
    )

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            LessonCreate(
                availability_id=online_availability.id,
                start_time=time(15),
                end_time=time(16),
                booking_ids=[remote_booking.id],
                association_subject_ids=[subject.id],
            ),
        )

    assert error.value.status_code == 400
    assert "docente" in error.value.detail


async def test_a_pupil_cannot_be_in_two_lessons_at_once(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    await service(db).create(payload(built))

    other_teacher = await make_teacher(db)
    subject = await make_discipline(db)
    await make_competence(db, other_teacher, subject)
    other_availability = await make_availability(
        db,
        other_teacher,
        day=DAY,
        start_time=time(14),
        end_time=time(19),
    )
    second_booking = await make_booking(
        db,
        built.presence,
        duration=60,
        association_subject_id=subject.id,
    )

    with pytest.raises(HTTPException) as error:
        await service(db).create(
            LessonCreate(
                availability_id=other_availability.id,
                start_time=time(15),
                end_time=time(16),
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
        await service(db).create(payload(built))

    assert error.value.status_code == 400
    assert "da casa" in error.value.detail


async def test_pupils_in_one_lesson_must_share_a_mode(db: AsyncSession) -> None:
    built = await scene(db)
    other = await scene(db, student_mode="online")

    with pytest.raises(HTTPException) as error:
        await service(db).create(
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
        await service(db).create(payload(built))

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

    lesson, warnings = await service(db).create(payload(built))

    assert lesson.id is not None
    assert len(warnings) == 1
    assert "non preferito" in warnings[0]


async def test_a_published_band_is_closed_to_new_lessons(db: AsyncSession) -> None:
    built = await scene(db)

    db.add(CalendarPublication(date=DAY, band="AFTERNOON"))
    await db.flush()

    with pytest.raises(HTTPException) as error:
        await service(db).create(payload(built))

    assert error.value.status_code == 409


# The morning going out does not freeze the afternoon.
async def test_another_band_being_published_changes_nothing(
    db: AsyncSession,
) -> None:
    built = await scene(db)

    db.add(CalendarPublication(date=DAY, band="MORNING"))
    await db.flush()

    lesson, _ = await service(db).create(payload(built))

    assert lesson.band == "AFTERNOON"


async def test_a_stale_write_is_rejected(db: AsyncSession) -> None:
    built = await scene(db, duration=120)
    lesson, _ = await service(db).create(payload(built))

    stale = LessonUpdate(
        availability_id=built.availability.id,
        start_time=time(15),
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
    lesson, _ = await service(db).create(payload(built))

    await service(db).delete(ADMIN_IDENTITY, lesson.id)

    remaining = await LessonRepository(db).get_by_id(
        lesson.id,
        visibility=LessonVisibility(),
    )

    assert remaining is None
