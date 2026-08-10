from collections.abc import Sequence
from typing import Final

from fastapi import HTTPException, status

from app.core.integrity import integrity_guard
from app.models.room import Room
from app.repositories.room_repository import RoomRepository
from app.schemas.room import RoomCreate, RoomUpdate

_NOT_FOUND_ERROR: Final[str] = "Stanza non trovata"
_DUPLICATE_NAME_ERROR: Final[str] = "Esiste già una stanza con questo nome."
_CREATE_ERROR: Final[str] = "Errore durante la creazione della stanza."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_IN_USE_ERROR: Final[str] = (
    "La stanza è assegnata in {count} giornate del calendario e non può essere "
    "eliminata."
)


class RoomService:
    def __init__(self, repository: RoomRepository) -> None:
        self.repository = repository

    # Case-insensitive, and checked before writing: the UNIQUE index would let
    # "Aula blu" stand beside "Aula Blu", and then nobody knows which one they
    # were sent to. The integrity_guard below still catches the race.
    async def _assert_name_available(
        self,
        name: str,
        *,
        exclude_id: int | None = None,
    ) -> None:
        existing = await self.repository.find_by_name(name, exclude_id=exclude_id)

        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_DUPLICATE_NAME_ERROR,
            )

    async def list_all(self) -> Sequence[Room]:
        return await self.repository.list()

    async def get_or_404(self, room_id: int) -> Room:
        room = await self.repository.get_by_id(room_id)

        if room is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return room

    async def create(self, payload: RoomCreate) -> Room:
        await self._assert_name_available(payload.name)

        room = Room(
            name=payload.name,
            description=payload.description,
            capacity=payload.capacity,
        )

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            await self.repository.create(room)
            await self.repository.commit()

        return room

    async def update(self, room_id: int, payload: RoomUpdate) -> Room:
        room = await self.get_or_404(room_id)

        await self._assert_name_available(payload.name, exclude_id=room.id)

        room.name = payload.name
        room.description = payload.description
        room.capacity = payload.capacity

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            await self.repository.commit()

        return room

    # A room that has ever been used is part of the record and stays. Counted
    # first so the refusal can say why; the RESTRICT is what holds if two
    # requests race.
    async def delete(self, room_id: int) -> None:
        room = await self.get_or_404(room_id)
        assignments = await self.repository.count_assignments(room.id)

        if assignments:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_IN_USE_ERROR.format(count=assignments),
            )

        async with integrity_guard(
            self.repository.session,
            _IN_USE_ERROR.format(count=assignments),
        ):
            await self.repository.delete(room)
            await self.repository.commit()
