# Realigns opening_days with weekly_templates.
#
# A one-off, for after the calendar has drifted: a standard band that changed its
# start time used to leave its already materialised rows behind, and those rows
# stayed in the calendar with no template declaring them.
#
# It rewrites the generated rows of every day from the templates, from the chosen
# date on. Overrides — holidays, closures and extraordinary openings — stay where
# they are: they do not come from the templates and take precedence. Teachers'
# availabilities on days that come out closed are removed, as on any closure.
#
#     python -m scripts.reconcile_opening_days --dry-run
#     python -m scripts.reconcile_opening_days

import argparse
import asyncio
from datetime import date, time
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.db.session import AsyncSessionLocal
from app.models.opening_day import OpeningDay
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.services.weekly_template_service import WeeklyTemplateService

_MODES: Final[tuple[str, ...]] = ("presence", "online")

_SnapshotRow = tuple[date, str, time | None, time | None]


# Overrides are left out on purpose: the reconcile never touches them, so a
# difference on one of those rows would be noise.
async def _snapshot(session: AsyncSession, date_from: date) -> list[_SnapshotRow]:
    rows = (
        await session.execute(
            select(
                OpeningDay.date,
                OpeningDay.mode,
                OpeningDay.start_time,
                OpeningDay.end_time,
            )
            .where(
                OpeningDay.date >= date_from,
                OpeningDay.is_override.is_(False),
            )
            .order_by(OpeningDay.date, OpeningDay.mode, OpeningDay.start_time)
        )
    ).all()

    return [tuple(row) for row in rows]


def _print_rows(rows: list[_SnapshotRow], marker: str) -> None:
    for day, mode, start_time, end_time in rows:
        print(f"  {marker} {day} {mode:<8} {start_time}-{end_time}")


async def main(date_from: date, dry_run: bool) -> None:
    async with AsyncSessionLocal() as session:
        before = await _snapshot(session, date_from)

        service = WeeklyTemplateService(
            WeeklyTemplateRepository(session),
            OpeningDayRepository(session),
        )

        for mode in _MODES:
            for weekday in range(1, 8):
                await service.reconcile_weekday(
                    weekday=weekday,
                    mode=mode,
                    effective_from=date_from,
                )

        after = await _snapshot(session, date_from)

        removed = sorted(set(before) - set(after))
        added = sorted(set(after) - set(before))

        _print_rows(removed, "-")
        _print_rows(added, "+")

        print()
        print(
            f"{len(removed)} righe tolte, {len(added)} righe scritte, "
            f"dal {date_from.isoformat()} in poi."
        )

        if dry_run:
            await session.rollback()
            print("Prova a vuoto: niente è stato salvato.")
        else:
            await session.commit()
            print("Riallineamento salvato.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Riallinea opening_days ai weekly_templates."
    )
    parser.add_argument(
        "--from",
        dest="date_from",
        type=date.fromisoformat,
        default=today_in_rome(),
        help="Data di partenza (default: oggi). Il passato non viene toccato.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostra le differenze senza salvarle.",
    )

    args = parser.parse_args()

    asyncio.run(main(args.date_from, args.dry_run))
