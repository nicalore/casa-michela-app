from collections.abc import Sequence
from typing import Final

from fastapi import HTTPException, status

from app.core.integrity import integrity_guard
from app.models.room import Room
from app.repositories.room_repository import RoomRepository
from app.schemas.room import RoomCreate, RoomUpdate
from app.services.bilingual import Bilingual

_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Stanza non trovata",
    "Room not found",
)
_DUPLICATE_NAME_ERROR: Final[Bilingual] = Bilingual(
    "Esiste già una stanza con questo nome.",
    "A room with this name already exists.",
)
_CREATE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante la creazione della stanza.",
    "Something went wrong while creating the room.",
)
_UPDATE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante l'aggiornamento.",
    "Something went wrong while saving.",
)

_IN_USE_ERROR: Final[Bilingual] = Bilingual(
    "La stanza è assegnata in {count} giornate del calendario e non può essere "
    "eliminata.",
    "The room is assigned on {count} calendar days and cannot be deleted.",
)
_IN_USE_ONE_DAY_ERROR: Final[Bilingual] = Bilingual(
    "La stanza è assegnata in 1 giornata del calendario e non può essere eliminata.",
    "The room is assigned on 1 calendar day and cannot be deleted.",
)


def _in_use_error(days: int) -> str:
    if days == 1:
        return _IN_USE_ONE_DAY_ERROR.for_request()

    return _IN_USE_ERROR.for_request().format(count=days)


class RoomService:
    def __init__(self, repository: RoomRepository) -> None:
        self.repository = repository

    # Case-insensitive pre-check: the UNIQUE index alone would allow "Aula blu"
    # beside "Aula Blu". integrity_guard still catches the race.
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
                detail=_DUPLICATE_NAME_ERROR.for_request(),
            )

    async def list_all(self) -> Sequence[Room]:
        return await self.repository.list()

    async def get_or_404(self, room_id: int) -> Room:
        room = await self.repository.get_by_id(room_id)

        if room is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR.for_request(),
            )

        return room

    async def create(self, payload: RoomCreate) -> Room:
        await self._assert_name_available(payload.name)

        room = Room(
            name=payload.name,
            description=payload.description,
            capacity=payload.capacity,
        )

        async with integrity_guard(

            self.repository.session,

            _CREATE_ERROR.for_request(),

        ):
            await self.repository.create(room)
            await self.repository.commit()

        return room

    async def update(self, room_id: int, payload: RoomUpdate) -> Room:
        room = await self.get_or_404(room_id)

        await self._assert_name_available(payload.name, exclude_id=room.id)

        room.name = payload.name
        room.description = payload.description
        room.capacity = payload.capacity

        async with integrity_guard(

            self.repository.session,

            _UPDATE_ERROR.for_request(),

        ):
            await self.repository.commit()

        return room

    # Counted first for a readable refusal; the RESTRICT holds under races.
    async def delete(self, room_id: int) -> None:
        room = await self.get_or_404(room_id)
        days = await self.repository.count_assigned_days(room.id)

        if days:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_in_use_error(days),
            )

        async with integrity_guard(
            self.repository.session,
            _in_use_error(days),
        ):
            await self.repository.delete(room)
            await self.repository.commit()
