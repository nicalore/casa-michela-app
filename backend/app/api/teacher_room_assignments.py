from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import require_role
from app.models.person import Person
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.schemas.teacher_room_assignment import (
    TeacherRoomAssignmentCreate,
    TeacherRoomAssignmentResponse,
    TeacherRoomAssignmentUpdate,
)
from app.services.teacher_room_assignment_service import (
    TeacherRoomAssignmentService,
)

# Readable by teachers, who have to know which room to go to; written by
# administrators, who decide.
router = APIRouter(
    prefix="/teacher-room-assignments",
    tags=["teacher-room-assignments"],
    dependencies=[Depends(require_role("ADMIN", "TEACHER"))],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _to_response(
    assignment: TeacherRoomAssignment,
    people: dict[str, Person],
    warnings: list[str],
) -> TeacherRoomAssignmentResponse:
    return TeacherRoomAssignmentResponse(
        date=assignment.date,
        teacher_tax_code=assignment.teacher_tax_code,
        teacher=PersonOption.model_validate(people[assignment.teacher_tax_code]),
        room=RoomOption.model_validate(assignment.room),
        warnings=warnings,
        created_at=assignment.created_at,
        updated_at=assignment.updated_at,
    )


async def _to_responses(
    db: DbSession,
    assignments: Sequence[TeacherRoomAssignment],
    *,
    warnings: list[str] | None = None,
) -> list[TeacherRoomAssignmentResponse]:
    people = await PersonRepository(db).get_options(
        assignment.teacher_tax_code for assignment in assignments
    )

    return [
        _to_response(assignment, people, warnings or [])
        for assignment in assignments
    ]


def _service(db: DbSession) -> TeacherRoomAssignmentService:
    return TeacherRoomAssignmentService(
        TeacherRoomAssignmentRepository(db),
        LessonRepository(db),
        RoomRepository(db),
    )


@router.get("/", response_model=list[TeacherRoomAssignmentResponse])
async def list_assignments(
    day: date,
    db: DbSession,
) -> list[TeacherRoomAssignmentResponse]:
    assignments = await _service(db).list_for_day(day)

    return await _to_responses(db, assignments)


@router.post(
    "/",
    response_model=TeacherRoomAssignmentResponse,
    dependencies=_ADMIN_ONLY,
)
async def assign_room(
    payload: TeacherRoomAssignmentCreate,
    db: DbSession,
) -> TeacherRoomAssignmentResponse:
    assignment, warnings = await _service(db).assign(payload)

    return (await _to_responses(db, [assignment], warnings=warnings))[0]


@router.put(
    "/{day}/{teacher_tax_code}",
    response_model=TeacherRoomAssignmentResponse,
    dependencies=_ADMIN_ONLY,
)
async def update_assignment(
    day: date,
    teacher_tax_code: str,
    payload: TeacherRoomAssignmentUpdate,
    db: DbSession,
) -> TeacherRoomAssignmentResponse:
    assignment, warnings = await _service(db).update(day, teacher_tax_code, payload)

    return (await _to_responses(db, [assignment], warnings=warnings))[0]


@router.delete("/{day}/{teacher_tax_code}", dependencies=_ADMIN_ONLY)
async def unassign_room(
    day: date,
    teacher_tax_code: str,
    db: DbSession,
) -> dict[str, str]:
    shifts = await _service(db).unassign(day, teacher_tax_code)

    # Said rather than discovered afterwards: the shifts went with it.
    detail = "Assegnazione rimossa"

    if shifts:
        detail = f"{detail} insieme a {shifts} turni di presidio"

    return {"detail": detail}
