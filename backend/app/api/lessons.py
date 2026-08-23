from collections.abc import Sequence
from datetime import date
from itertools import chain

from fastapi import APIRouter, Depends

from app.api.booking_presentation import booking_summary, teacher_tax_codes
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.lesson import Lesson
from app.models.person import Person
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.booking import BookingResponse, PresenceSummary
from app.schemas.lesson import LessonCreate, LessonResponse, LessonUpdate
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.services.lesson_service import LessonService

router = APIRouter(
    prefix="/lessons",
    tags=["lessons"],
    dependencies=[Depends(require_role("ADMIN", "TEACHER", "STUDENT", "PARENT"))],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _booking_responses(
    lesson: Lesson,
    people: dict[str, Person],
) -> list[BookingResponse]:
    responses = []

    for link in lesson.lesson_bookings:
        booking = link.booking
        presence = booking.presence

        responses.append(
            BookingResponse(
                **booking_summary(booking, people).model_dump(),
                presence_id=booking.presence_id,
                presence=PresenceSummary(
                    id=presence.id,
                    date=presence.date,
                    start_time=presence.start_time,
                    end_time=presence.end_time,
                    student=PersonOption.model_validate(
                        people[presence.student_tax_code],
                    ),
                ),
            ),
        )

    return responses


def _to_response(
    lesson: Lesson,
    people: dict[str, Person],
    rooms: dict[tuple[date, str], TeacherRoomAssignment],
    settled: set[tuple[date, str]],
    warnings: list[str],
) -> LessonResponse:
    teacher_tax_code = lesson.availability.teacher_tax_code
    assignment = rooms.get((lesson.date, teacher_tax_code))

    return LessonResponse(
        id=lesson.id,
        availability_id=lesson.availability_id,
        teacher_tax_code=teacher_tax_code,
        teacher=PersonOption.model_validate(people[teacher_tax_code]),
        date=lesson.date,
        teacher_mode=OpeningModeEnum(lesson.teacher_mode),
        mode=OpeningModeEnum(lesson.mode),
        band=TimeBandEnum(lesson.band),
        start_time=lesson.start_time,
        end_time=lesson.end_time,
        room=(
            RoomOption.model_validate(assignment.room)
            if assignment is not None
            else None
        ),
        disciplines=[
            AssociationSubjectOption.model_validate(row.association_subject)
            for row in lesson.lesson_disciplines
        ],
        bookings=_booking_responses(lesson, people),
        is_locked=(lesson.date, lesson.band) in settled,
        warnings=warnings,
        created_at=lesson.created_at,
        updated_at=lesson.updated_at,
    )


async def _to_responses(
    db: DbSession,
    lessons: Sequence[Lesson],
    *,
    warnings: list[str] | None = None,
) -> list[LessonResponse]:
    if not lessons:
        return []

    bookings = [link.booking for lesson in lessons for link in lesson.lesson_bookings]
    people = await PersonRepository(db).get_options(
        chain(
            (lesson.availability.teacher_tax_code for lesson in lessons),
            (booking.presence.student_tax_code for booking in bookings),
            teacher_tax_codes(bookings),
        ),
    )

    assignments = TeacherRoomAssignmentRepository(db)
    rooms: dict[tuple[date, str], TeacherRoomAssignment] = {}

    for day in {lesson.date for lesson in lessons}:
        for assignment in await assignments.list_for_day(day):
            rooms[(day, assignment.teacher_tax_code)] = assignment

    settled = await CalendarPublicationRepository(db).find_settled_pairs(
        {(lesson.date, lesson.band) for lesson in lessons},
    )

    return [
        _to_response(lesson, people, rooms, settled, warnings or [])
        for lesson in lessons
    ]


def _service(db: DbSession) -> LessonService:
    return LessonService(LessonRepository(db))


@router.get("/", response_model=list[LessonResponse])
async def list_lessons(
    identity: CurrentIdentity,
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
    band: TimeBandEnum | None = None,
    mode: OpeningModeEnum | None = None,
    teacher_tax_code: str | None = None,
) -> list[LessonResponse]:
    lessons = await _service(db).list_for(
        identity,
        date_from=date_from,
        date_to=date_to,
        band=str(band) if band is not None else None,
        mode=str(mode) if mode is not None else None,
        teacher_tax_code=teacher_tax_code,
    )

    return await _to_responses(db, lessons)


@router.post("/", response_model=LessonResponse, dependencies=_ADMIN_ONLY)
async def create_lesson(payload: LessonCreate, db: DbSession) -> LessonResponse:
    lesson, warnings = await _service(db).create(payload)

    return (await _to_responses(db, [lesson], warnings=warnings))[0]


@router.get("/{lesson_id}", response_model=LessonResponse)
async def get_lesson(
    lesson_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> LessonResponse:
    lesson = await _service(db).get_visible_or_404(identity, lesson_id)

    return (await _to_responses(db, [lesson]))[0]


@router.put("/{lesson_id}", response_model=LessonResponse, dependencies=_ADMIN_ONLY)
async def update_lesson(
    lesson_id: int,
    payload: LessonUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> LessonResponse:
    lesson, warnings = await _service(db).update(identity, lesson_id, payload)

    return (await _to_responses(db, [lesson], warnings=warnings))[0]


@router.delete("/{lesson_id}", dependencies=_ADMIN_ONLY)
async def delete_lesson(
    lesson_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _service(db).delete(identity, lesson_id)

    return {"detail": "Lezione eliminata"}
