# Generates opening_days out of weekly_templates.
#
# Periodic run, from an external cron in early December: generates the whole
# year following the current one.
#
#     python -m scripts.generate_opening_days
#
# One-off bootstrap, needed only when first populating the database, before any
# periodic run has ever happened: generates from an explicit range.
#
#     python -m scripts.generate_opening_days --start 2026-07-27 --end 2026-12-31

import argparse
import asyncio
import sys
from datetime import date

from app.core.booking_window import today_in_rome
from app.db.session import AsyncSessionLocal
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.services.opening_day_generation_service import OpeningDayGenerationService


def _default_range() -> tuple[date, date]:
    next_year = today_in_rome().year + 1

    return date(next_year, 1, 1), date(next_year, 12, 31)


async def main(start_date: date, end_date: date) -> None:
    async with AsyncSessionLocal() as session:
        service = OpeningDayGenerationService(
            OpeningDayRepository(session),
            WeeklyTemplateRepository(session),
        )
        result = await service.generate_opening_days(start_date, end_date)

    print(
        f"Generazione {start_date.isoformat()} -> {end_date.isoformat()}: "
        f"{result.dates_processed} date processate, "
        f"{result.rows_created} righe create, "
        f"{result.rows_skipped_existing} righe già esistenti saltate."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Genera opening_days a partire da weekly_templates"
    )
    parser.add_argument(
        "--start",
        type=date.fromisoformat,
        default=None,
        help="Data di inizio (YYYY-MM-DD). Default: 1 gennaio dell'anno successivo.",
    )
    parser.add_argument(
        "--end",
        type=date.fromisoformat,
        default=None,
        help="Data di fine (YYYY-MM-DD). Default: 31 dicembre dell'anno successivo.",
    )
    args = parser.parse_args()

    if (args.start is None) != (args.end is None):
        print("--start e --end vanno specificati insieme.", file=sys.stderr)
        raise SystemExit(1)

    if args.start is not None and args.end is not None:
        selected_start, selected_end = args.start, args.end
    else:
        selected_start, selected_end = _default_range()

    try:
        asyncio.run(main(selected_start, selected_end))
    except ValueError as err:
        print(f"Errore: {err}", file=sys.stderr)
        raise SystemExit(1) from err
