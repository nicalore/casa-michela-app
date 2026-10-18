import asyncio
import logging
from datetime import UTC, datetime
from typing import Final

from app.core.booking_close import now_in_rome
from app.db.session import AsyncSessionLocal
from app.services.arrival_reminders import remind_arrivals
from app.services.daily_reminders import remind_tomorrow
from app.services.notifications import expire
from app.services.push import deliver, forget_ended_sessions
from app.services.rating_reminders import remind_ratings
from app.services.week_opened import announce_opened_week

# Times are whole minutes: just past one, everything due at it has come.
_PAST_MINUTE: Final[float] = 1.0

logger = logging.getLogger("minute-sweep")


async def _expire() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await expire(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Ritiro delle notifiche scadute non riuscito.")


async def _forget_ended_sessions() -> None:
    try:
        async with AsyncSessionLocal() as session:
            await forget_ended_sessions(session, datetime.now(UTC))

    except Exception:
        logger.exception("Pulizia dei dispositivi disconnessi non riuscita.")


async def _remind() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await remind_arrivals(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Promemoria di entrata non riuscito.")


async def _announce_week() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await announce_opened_week(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Avviso della settimana aperta non riuscito.")


async def _remind_tomorrow() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await remind_tomorrow(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Promemoria per domani non riuscito.")


async def _remind_ratings() -> None:
    try:
        async with AsyncSessionLocal() as session:
            batch = await remind_ratings(session, now_in_rome())
            await session.commit()

        await deliver(batch)

    except Exception:
        logger.exception("Promemoria delle valutazioni non riuscito.")


# Startup hook: runs at once, for what fell due while down, then every minute.
async def sweep_every_minute() -> None:
    while True:
        await _expire()
        await _forget_ended_sessions()
        await _remind()
        await _announce_week()
        await _remind_tomorrow()
        await _remind_ratings()

        now = now_in_rome()
        await asyncio.sleep(
            60 - now.second - now.microsecond / 1_000_000 + _PAST_MINUTE,
        )
