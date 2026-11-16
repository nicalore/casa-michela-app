from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession, AsyncSessionTransaction

from app.services.calendar_hours_sync import LOST_ERROR


class Losses:
    """What one write would delete, asked once for all of it. Until confirmed the
    write runs in a savepoint, undone before asking."""

    def __init__(self, db: AsyncSession, *, confirm: bool) -> None:
        self._db = db
        self.confirm = confirm
        self._said: list[str] = []
        self._savepoint: AsyncSessionTransaction | None = None

    # Before the write's first change.
    async def open(self) -> None:
        if not self.confirm:
            self._savepoint = await self._db.begin_nested()

    def note(self, sentence: str) -> None:
        if not self.confirm:
            self._said.append(sentence)

    # Before the commit.
    async def settle(self) -> None:
        if not self._said:
            return

        if self._savepoint is not None:
            await self._savepoint.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": LOST_ERROR, "message": " ".join(self._said)},
        )
