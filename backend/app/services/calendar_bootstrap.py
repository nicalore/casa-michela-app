from __future__ import annotations

import logging
from datetime import date
from typing import Final

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.db.session import AsyncSessionLocal
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.services.opening_day_generation_service import (
    GenerationResult,
    OpeningDayGenerationService,
)

_MODES: Final[tuple[str, ...]] = ("presence", "online")

# The month the yearly generation runs in, materialising the whole year after.
_GENERATION_MONTH: Final[int] = 12

# Nothing here is worth waiting on. A TRUNCATE or an ALTER on opening_days holds
# an ACCESS EXCLUSIVE lock until its transaction ends, and a lock wait has no
# deadline of its own: without these the bootstrap would sit on it forever.
_LOCK_TIMEOUT: Final[str] = "5s"
_STATEMENT_TIMEOUT: Final[str] = "60s"

logger = logging.getLogger("calendar-bootstrap")


# Mirrors calendarHorizon() in the frontend's calendar_bounds.dart: 31 December
# of the current year, and of the next one from December on, which is when the
# yearly generation produces it. The calendar cannot be browsed past that date,
# so there is nothing to gain by materialising beyond it.
def calendar_horizon(today: date) -> date:
    year = today.year + 1 if today.month >= _GENERATION_MONTH else today.year

    return date(year, 12, 31)


# Whether the calendar fails to reach today in at least one mode, which is the
# state a database that has never been generated is in: the migrations create
# the tables and seed weekly_templates, they materialise no opening_day at all.
#
# A calendar whose last day is already behind us is the same case: it stopped
# being a calendar, and everything bounded by "the last materialised date" —
# which is every propagation of the standard hours — silently does nothing.
async def _needs_bootstrap(repository: OpeningDayRepository, today: date) -> bool:
    for mode in _MODES:
        last_generated = await repository.last_generated_date(mode)

        if last_generated is None or last_generated < today:
            return True

    return False


# Generates from today to the horizon when the calendar does not reach today,
# exactly as the one-off run of scripts/generate_opening_days does — holidays
# included, and skipping whatever is already materialised. Returns None when
# there was nothing to do.
#
# The generation stays script-only for the yearly run: this is not a second way
# of producing the calendar, it is the guarantee that a fresh environment has
# one at all. Without it the association's hours can be saved from the UI, be
# reported as saved, and reach no day of the calendar, since propagation is
# bounded by the last materialised date and there is none.
async def bootstrap_calendar(session: AsyncSession) -> GenerationResult | None:
    opening_days = OpeningDayRepository(session)
    today = today_in_rome()

    if not await _needs_bootstrap(opening_days, today):
        return None

    service = OpeningDayGenerationService(
        opening_days,
        WeeklyTemplateRepository(session),
    )

    return await service.generate_opening_days(today, calendar_horizon(today))


# Bounded on its own connection, never on the pool's shared settings: whatever
# the bootstrap runs into, it gives up rather than holding on.
async def _bound_waiting(session: AsyncSession) -> None:
    await session.execute(text(f"SET lock_timeout = '{_LOCK_TIMEOUT}'"))
    await session.execute(text(f"SET statement_timeout = '{_STATEMENT_TIMEOUT}'"))


# Startup hook. A calendar that could not be written is a degraded app, not a
# dead one: the failure is logged and the API serves regardless, because a
# calendar is one feature and refusing to start takes down all of them.
#
# Run detached by the lifespan for the same reason, so nothing about the
# database — unreachable, locked, slow — can keep the port from opening.
async def bootstrap_calendar_on_startup() -> None:
    try:
        async with AsyncSessionLocal() as session:
            await _bound_waiting(session)

            result = await bootstrap_calendar(session)

    except Exception:
        logger.exception("Bootstrap del calendario non riuscito.")

        return

    if result is None:
        logger.info("Calendario già materializzato: nessun bootstrap necessario.")

        return

    logger.info(
        "Bootstrap del calendario: %d date processate, %d righe create, "
        "%d righe già esistenti saltate.",
        result.dates_processed,
        result.rows_created,
        result.rows_skipped_existing,
    )
