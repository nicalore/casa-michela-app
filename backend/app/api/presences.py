from collections.abc import Sequence
from datetime import date
from itertools import chain

from fastapi import APIRouter, Depends

from app.api.booking_presentation import booking_summaries, teacher_tax_codes
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.models.person import Person
from app.models.presence import Presence
from app.repositories.person_repository import PersonRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.person import PersonOption
from app.schemas.presence import PresenceCreate, PresenceResponse, PresenceUpdate
from app.services.presence_service import PresenceService

router = APIRouter(
    prefix="/presences",
    tags=["presences"],
    dependencies=[Depends(require_role("PARENT", "STUDENT", "ADMIN"))],
)


def _to_response(presence: Presence, people: dict[str, Person]) -> PresenceResponse:
    return PresenceResponse(
        id=presence.id,
        date=presence.date,
        mode=presence.mode,
        start_time=presence.start_time,
        end_time=presence.end_time,
        student_tax_code=presence.student_tax_code,
        student=PersonOption.model_validate(people[presence.student_tax_code]),
        booker_tax_code=presence.booker_tax_code,
        booker=PersonOption.model_validate(people[presence.booker_tax_code]),
        bookings=booking_summaries(presence.bookings, people),
        created_at=presence.created_at,
        updated_at=presence.updated_at,
    )


async def to_responses(
    db: DbSession,
    presences: Sequence[Presence],
) -> list[PresenceResponse]:
    tax_codes = chain(
        chain.from_iterable(
            (p.student_tax_code, p.booker_tax_code) for p in presences
        ),
        teacher_tax_codes(
            booking for presence in presences for booking in presence.bookings
        ),
    )
    people = await PersonRepository(db).get_options(tax_codes)

    return [_to_response(presence, people) for presence in presences]


@router.get("/", response_model=list[PresenceResponse])
async def list_presences(
    identity: CurrentIdentity,
    db: DbSession,
    student_tax_code: str | None = None,
    booker_tax_code: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[PresenceResponse]:
    service = PresenceService(PresenceRepository(db))
    presences = await service.list_for(
        identity,
        student_tax_code=student_tax_code,
        booker_tax_code=booker_tax_code,
        date_from=date_from,
        date_to=date_to,
    )

    return await to_responses(db, presences)


@router.post("/", response_model=PresenceResponse)
async def create_presence(
    payload: PresenceCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> PresenceResponse:
    service = PresenceService(PresenceRepository(db))
    presence = await service.create(identity, payload)

    return (await to_responses(db, [presence]))[0]


@router.get("/{presence_id}", response_model=PresenceResponse)
async def get_presence(
    presence_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> PresenceResponse:
    service = PresenceService(PresenceRepository(db))
    presence = await service.get_owned_or_404(identity, presence_id)

    return (await to_responses(db, [presence]))[0]


@router.put("/{presence_id}", response_model=PresenceResponse)
async def update_presence(
    presence_id: int,
    payload: PresenceUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> PresenceResponse:
    service = PresenceService(PresenceRepository(db))
    presence = await service.update(identity, presence_id, payload)

    return (await to_responses(db, [presence]))[0]


@router.delete("/{presence_id}")
async def delete_presence(
    presence_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    service = PresenceService(PresenceRepository(db))
    await service.delete(identity, presence_id)

    return {"detail": "Presenza eliminata"}
