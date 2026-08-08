from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession


# A constraint the database enforces, and that the service cannot check without
# losing a race, surfaces here as an IntegrityError. The transaction is unwound
# first, so the session is usable again, and the failure reaches the caller as a
# 400 carrying a message they can read.
@asynccontextmanager
async def integrity_guard(session: AsyncSession, detail: str) -> AsyncIterator[None]:
    try:
        yield

    except IntegrityError as err:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        ) from err
