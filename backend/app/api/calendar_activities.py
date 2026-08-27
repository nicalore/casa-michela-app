from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.calendar_activity import CalendarActivity
from app.models.person import Person
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.person_repository import PersonRepository
from app.schemas.calendar_activity import (
    CalendarActivityCreate,
    CalendarActivityPlacement,
    CalendarActivityResponse,
    CalendarActivityUpdate,
)
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.services.calendar_activity_service import CalendarActivityService

router = APIRouter(
    prefix="/calendar-activities",
    tags=["calendar-activities"],
    # Same four roles the lessons answer to; the service decides what each sees.
    dependencies=[Depends(require_role("ADMIN", "TEACHER", "STUDENT", "PARENT"))],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _placement(
    activity: CalendarActivity,
    people: dict[str, Person],
) -> CalendarActivityPlacement | None:
    availability = activity.availability

    if availability is None:
        return None

    teacher = people.get(availability.teacher_tax_code)

    if teacher is None:
        return None

    return CalendarActivityPlacement(
        availability_id=availability.id,
        teacher_tax_code=availability.teacher_tax_code,
        teacher=PersonOption.model_validate(teacher),
        teacher_mode=OpeningModeEnum(availability.mode),
        start_time=activity.start_time,
        end_time=activity.end_time,
    )


def _to_response(
    activity: CalendarActivity,
    people: dict[str, Person],
    settled: set[tuple[date, str]],
) -> CalendarActivityResponse:
    return CalendarActivityResponse(
        id=activity.id,
        date=activity.date,
        band=TimeBandEnum(activity.band),
        name=activity.name,
        description=activity.description,
        placement=_placement(activity, people),
        is_locked=(activity.date, activity.band) in settled,
        created_at=activity.created_at,
        updated_at=activity.updated_at,
    )


async def _to_responses(
    db: DbSession,
    service: CalendarActivityService,
    activities: Sequence[CalendarActivity],
) -> list[CalendarActivityResponse]:
    if not activities:
        return []

    people = await PersonRepository(db).get_options(
        activity.availability.teacher_tax_code
        for activity in activities
        if activity.availability is not None
    )

    settled = await service.settled_bands(activities)

    return [_to_response(activity, people, settled) for activity in activities]


def _service(db: DbSession) -> CalendarActivityService:
    return CalendarActivityService(CalendarActivityRepository(db))


@router.get("/", response_model=list[CalendarActivityResponse])
async def list_activities(
    identity: CurrentIdentity,
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[CalendarActivityResponse]:
    service = _service(db)
    activities = await service.list_for(
        identity,
        date_from=date_from,
        date_to=date_to,
    )

    return await _to_responses(db, service, activities)


@router.post("/", response_model=CalendarActivityResponse, dependencies=_ADMIN_ONLY)
async def create_activity(
    payload: CalendarActivityCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarActivityResponse:
    service = _service(db)
    activity = await service.create(identity, payload)

    return (await _to_responses(db, service, [activity]))[0]


@router.put(
    "/{activity_id}",
    response_model=CalendarActivityResponse,
    dependencies=_ADMIN_ONLY,
)
async def update_activity(
    activity_id: int,
    payload: CalendarActivityUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarActivityResponse:
    service = _service(db)
    activity = await service.update(identity, activity_id, payload)

    return (await _to_responses(db, service, [activity]))[0]


@router.delete("/{activity_id}", dependencies=_ADMIN_ONLY)
async def delete_activity(
    activity_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _service(db).delete(identity, activity_id)

    return {"detail": "Attività eliminata"}
