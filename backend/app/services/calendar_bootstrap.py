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

# TRUNCATE/ALTER on opening_days holds ACCESS EXCLUSIVE with no lock-wait
# deadline of its own; without these timeouts the bootstrap could hang forever.
_LOCK_TIMEOUT: Final[str] = "5s"
_STATEMENT_TIMEOUT: Final[str] = "60s"

logger = logging.getLogger("calendar-bootstrap")


# Mirrors calendarHorizon() in the frontend's calendar_bounds.dart: 31 December
# of this year (of next year from December on); the UI cannot browse past it.
def calendar_horizon(today: date) -> date:
    year = today.year + 1 if today.month >= _GENERATION_MONTH else today.year

    return date(year, 12, 31)


# A calendar not reaching today in some mode marks a never-generated or
# stale database.
async def _needs_bootstrap(repository: OpeningDayRepository, today: date) -> bool:
    for mode in _MODES:
        last_generated = await repository.last_generated_date(mode)

        if last_generated is None or last_generated < today:
            return True

    return False


# Same generation as scripts/generate_opening_days, skipping materialised
# days; guarantees a fresh environment has a calendar. None when nothing to do.
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


# Timeouts are set on this connection only, never on the pool's shared settings.
async def _bound_waiting(session: AsyncSession) -> None:
    await session.execute(text(f"SET lock_timeout = '{_LOCK_TIMEOUT}'"))
    await session.execute(text(f"SET statement_timeout = '{_STATEMENT_TIMEOUT}'"))


# Startup hook: failures are logged and the API serves regardless; run
# detached so nothing about the database can keep the port from opening.
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
