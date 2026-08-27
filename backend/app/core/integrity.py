from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession


# Unwinds the transaction after an IntegrityError and surfaces it as a
# readable 400; the session stays usable.
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
