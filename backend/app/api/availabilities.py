from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.models.availability import Availability
from app.models.person import Person
from app.repositories.availability_repository import AvailabilityRepository
from app.repositories.person_repository import PersonRepository
from app.schemas.availability import (
    AvailabilityCreate,
    AvailabilityResponse,
    AvailabilityUpdate,
)
from app.schemas.person import PersonOption
from app.services.availability_service import AvailabilityService

router = APIRouter(
    prefix="/availabilities",
    tags=["availabilities"],
    dependencies=[Depends(require_role("TEACHER", "ADMIN"))],
)


def _to_response(
    availability: Availability,
    people: dict[str, Person],
) -> AvailabilityResponse:
    teacher = people[availability.teacher_tax_code]

    return AvailabilityResponse(
        id=availability.id,
        date=availability.date,
        mode=availability.mode,
        start_time=availability.start_time,
        end_time=availability.end_time,
        teacher_tax_code=availability.teacher_tax_code,
        teacher=PersonOption.model_validate(teacher),
        created_at=availability.created_at,
        updated_at=availability.updated_at,
    )


async def _to_responses(
    db: DbSession,
    availabilities: Sequence[Availability],
) -> list[AvailabilityResponse]:
    people = await PersonRepository(db).get_options(
        a.teacher_tax_code for a in availabilities
    )

    return [_to_response(a, people) for a in availabilities]


@router.get("/", response_model=list[AvailabilityResponse])
async def list_availabilities(
    identity: CurrentIdentity,
    db: DbSession,
    teacher_tax_code: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[AvailabilityResponse]:
    service = AvailabilityService(AvailabilityRepository(db))
    availabilities = await service.list_for(
        identity,
        teacher_tax_code=teacher_tax_code,
        date_from=date_from,
        date_to=date_to,
    )

    return await _to_responses(db, availabilities)


@router.post("/", response_model=AvailabilityResponse)
async def create_availability(
    payload: AvailabilityCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> AvailabilityResponse:
    service = AvailabilityService(AvailabilityRepository(db))
    availability = await service.create(identity, payload)

    return (await _to_responses(db, [availability]))[0]


@router.get("/{availability_id}", response_model=AvailabilityResponse)
async def get_availability(
    availability_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> AvailabilityResponse:
    service = AvailabilityService(AvailabilityRepository(db))
    availability = await service.get_owned_or_404(identity, availability_id)

    return (await _to_responses(db, [availability]))[0]


@router.put("/{availability_id}", response_model=AvailabilityResponse)
async def update_availability(
    availability_id: int,
    payload: AvailabilityUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> AvailabilityResponse:
    service = AvailabilityService(AvailabilityRepository(db))
    availability = await service.update(identity, availability_id, payload)

    return (await _to_responses(db, [availability]))[0]


@router.delete("/{availability_id}")
async def delete_availability(
    availability_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    service = AvailabilityService(AvailabilityRepository(db))
    await service.delete(identity, availability_id)

    return {"detail": "Disponibilità eliminata"}
