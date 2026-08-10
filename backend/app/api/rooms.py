from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import require_role
from app.repositories.room_repository import RoomRepository
from app.schemas.room import RoomCreate, RoomResponse, RoomUpdate
from app.services.room_service import RoomService

# Administrators only, throughout. A teacher never needs to browse the
# catalogue: the room they are in arrives inside the lesson itself.
router = APIRouter(
    prefix="/rooms",
    tags=["rooms"],
    dependencies=[Depends(require_role("ADMIN"))],
)


def _service(db: DbSession) -> RoomService:
    return RoomService(RoomRepository(db))


@router.get("/", response_model=list[RoomResponse])
async def list_rooms(db: DbSession) -> list[RoomResponse]:
    rooms = await _service(db).list_all()

    return [RoomResponse.model_validate(room) for room in rooms]


@router.post("/", response_model=RoomResponse)
async def create_room(payload: RoomCreate, db: DbSession) -> RoomResponse:
    room = await _service(db).create(payload)

    return RoomResponse.model_validate(room)


@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(room_id: int, db: DbSession) -> RoomResponse:
    room = await _service(db).get_or_404(room_id)

    return RoomResponse.model_validate(room)


@router.put("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: int,
    payload: RoomUpdate,
    db: DbSession,
) -> RoomResponse:
    room = await _service(db).update(room_id, payload)

    return RoomResponse.model_validate(room)


@router.delete("/{room_id}")
async def delete_room(room_id: int, db: DbSession) -> dict[str, str]:
    await _service(db).delete(room_id)

    return {"detail": "Stanza eliminata"}
