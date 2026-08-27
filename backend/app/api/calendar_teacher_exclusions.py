from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.calendar_teacher_exclusion import CalendarTeacherExclusion
from app.models.person import Person
from app.repositories.calendar_teacher_exclusion_repository import (
    CalendarTeacherExclusionRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.schemas.calendar_teacher_exclusion import (
    CalendarTeacherExclusionCreate,
    CalendarTeacherExclusionResponse,
)
from app.schemas.person import PersonOption
from app.services.calendar_teacher_exclusion_service import (
    CalendarTeacherExclusionService,
)

# Administrators only, like the calendar itself.
router = APIRouter(
    prefix="/calendar-teacher-exclusions",
    tags=["calendar-teacher-exclusions"],
    dependencies=[Depends(require_role("ADMIN"))],
)


def _to_response(
    exclusion: CalendarTeacherExclusion,
    people: dict[str, Person],
    *,
    unplanned_lessons: int = 0,
    unassigned_activities: int = 0,
) -> CalendarTeacherExclusionResponse:
    teacher = people.get(exclusion.teacher_tax_code)

    return CalendarTeacherExclusionResponse(
        date=exclusion.date,
        band=TimeBandEnum(exclusion.band),
        teacher_tax_code=exclusion.teacher_tax_code,
        teacher=PersonOption.model_validate(teacher) if teacher is not None else None,
        unplanned_lessons=unplanned_lessons,
        unassigned_activities=unassigned_activities,
        created_at=exclusion.created_at,
    )


async def _to_responses(
    db: DbSession,
    exclusions: Sequence[CalendarTeacherExclusion],
) -> list[CalendarTeacherExclusionResponse]:
    if not exclusions:
        return []

    people = await PersonRepository(db).get_options(
        exclusion.teacher_tax_code for exclusion in exclusions
    )

    return [_to_response(exclusion, people) for exclusion in exclusions]


def _service(db: DbSession) -> CalendarTeacherExclusionService:
    return CalendarTeacherExclusionService(
        CalendarTeacherExclusionRepository(db),
        LessonRepository(db),
    )


@router.get("/", response_model=list[CalendarTeacherExclusionResponse])
async def list_exclusions(
    db: DbSession,
    exclusion_date: date,
    band: TimeBandEnum,
) -> list[CalendarTeacherExclusionResponse]:
    return await _to_responses(
        db,
        await _service(db).list_for_band(exclusion_date, str(band)),
    )


@router.post("/", response_model=CalendarTeacherExclusionResponse)
async def exclude_teacher(
    payload: CalendarTeacherExclusionCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarTeacherExclusionResponse:
    exclusion, unplanned, handed_back = await _service(db).exclude(
        identity,
        payload,
    )

    people = await PersonRepository(db).get_options([exclusion.teacher_tax_code])

    return _to_response(
        exclusion,
        people,
        unplanned_lessons=unplanned,
        unassigned_activities=handed_back,
    )


@router.delete("/{exclusion_date}/{band}/{teacher_tax_code}")
async def readmit_teacher(
    exclusion_date: date,
    band: TimeBandEnum,
    teacher_tax_code: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _service(db).readmit(
        identity,
        exclusion_date,
        str(band),
        teacher_tax_code,
    )

    return {"detail": "Docente riaggiunto al calendario"}
