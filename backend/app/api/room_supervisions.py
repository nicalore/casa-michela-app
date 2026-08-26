from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.models.person import Person
from app.models.room import Room
from app.models.room_supervision import RoomSupervision
from app.repositories.person_repository import PersonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.schemas.room_supervision import (
    RoomSupervisionCreate,
    RoomSupervisionResponse,
    RoomSupervisionUpdate,
)
from app.services.room_supervision_service import RoomSupervisionService

router = APIRouter(
    prefix="/room-supervisions",
    tags=["room-supervisions"],
    dependencies=[Depends(require_role("ADMIN", "TEACHER"))],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _to_response(
    supervision: RoomSupervision,
    people: dict[str, Person],
    rooms: dict[int, Room],
) -> RoomSupervisionResponse:
    return RoomSupervisionResponse(
        id=supervision.id,
        date=supervision.date,
        teacher_tax_code=supervision.teacher_tax_code,
        teacher=PersonOption.model_validate(people[supervision.teacher_tax_code]),
        room=RoomOption.model_validate(rooms[supervision.room_id]),
        start_time=supervision.start_time,
        end_time=supervision.end_time,
        created_at=supervision.created_at,
        updated_at=supervision.updated_at,
    )


async def _to_responses(
    db: DbSession,
    supervisions: Sequence[RoomSupervision],
) -> list[RoomSupervisionResponse]:
    if not supervisions:
        return []

    people = await PersonRepository(db).get_options(
        supervision.teacher_tax_code for supervision in supervisions
    )
    rooms = {
        room.id: room
        for room in await RoomRepository(db).find_by_ids(
            [supervision.room_id for supervision in supervisions],
        )
    }

    return [
        _to_response(supervision, people, rooms) for supervision in supervisions
    ]


def _service(db: DbSession) -> RoomSupervisionService:
    return RoomSupervisionService(
        RoomSupervisionRepository(db),
        TeacherRoomAssignmentRepository(db),
    )


@router.get("/", response_model=list[RoomSupervisionResponse])
async def list_supervisions(
    day: date,
    db: DbSession,
    room_id: int | None = None,
) -> list[RoomSupervisionResponse]:
    supervisions = await _service(db).list_for_day(day, room_id=room_id)

    return await _to_responses(db, supervisions)


@router.post("/", response_model=RoomSupervisionResponse, dependencies=_ADMIN_ONLY)
async def create_supervision(
    payload: RoomSupervisionCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> RoomSupervisionResponse:
    supervision = await _service(db).create(identity, payload)

    return (await _to_responses(db, [supervision]))[0]


@router.put(
    "/{supervision_id}",
    response_model=RoomSupervisionResponse,
    dependencies=_ADMIN_ONLY,
)
async def update_supervision(
    supervision_id: int,
    payload: RoomSupervisionUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> RoomSupervisionResponse:
    supervision = await _service(db).update(identity, supervision_id, payload)

    return (await _to_responses(db, [supervision]))[0]


@router.delete("/{supervision_id}", dependencies=_ADMIN_ONLY)
async def delete_supervision(
    supervision_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _service(db).delete(identity, supervision_id)

    return {"detail": "Responsabilità eliminata"}
