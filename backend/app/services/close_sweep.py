import asyncio
import logging
from datetime import timedelta
from typing import Final

from app.core.booking_close import next_close, now_in_rome
from app.db.session import AsyncSessionLocal
from app.services.bookings_closed import announce_closed_bands
from app.services.collaboration import settle_collaborations
from app.services.push import deliver

# Requests let in just before a close may still be committing.
_AFTER_CLOSE: Final[timedelta] = timedelta(seconds=5)

logger = logging.getLogger("close-sweep")


async def _settle() -> None:
    try:
        async with AsyncSessionLocal() as session:
            await settle_collaborations(session)
            await session.commit()

    except Exception:
        logger.exception("Ripresa delle collaborazioni non riuscita.")


async def _announce() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await announce_closed_bands(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Avviso di chiusura delle prenotazioni non riuscito.")


# Startup hook: runs at once, for closes missed while down, then after each close.
async def sweep_after_every_close() -> None:
    while True:
        await _settle()
        await _announce()

        now = now_in_rome()
        wake = next_close(now - _AFTER_CLOSE) + _AFTER_CLOSE

        # Timestamps: across a DST change wall clocks are an hour off.
        await asyncio.sleep(wake.timestamp() - now.timestamp())
