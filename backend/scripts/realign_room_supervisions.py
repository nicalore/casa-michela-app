# Fits the shifts of published bands to their lessons, as publishing now does.
# Usage: python -m scripts.realign_room_supervisions [--from YYYY-MM-DD] [--dry-run]

import argparse
import asyncio
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.db.session import AsyncSessionLocal
from app.models.calendar_publication import CalendarPublication
from app.models.confirmed_hours import ConfirmedBand
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.services.room_supervision_service import realign_shifts

_ShiftRow = tuple[date, str, int, str]


async def _shifts(session: AsyncSession, day: date) -> set[_ShiftRow]:
    return {
        (
            row.date,
            row.teacher_tax_code,
            row.room_id,
            f"{row.start_time:%H:%M}-{row.end_time:%H:%M}",
        )
        for row in await RoomSupervisionRepository(session).list_for_day(day)
    }


# Drafts are left to their own republication; confirmed bands never change.
async def _bands(session: AsyncSession, date_from: date) -> list[tuple[date, str]]:
    confirmed = {
        (row.date, row.band)
        for row in (
            await session.execute(
                select(ConfirmedBand.date, ConfirmedBand.band).where(
                    ConfirmedBand.date >= date_from,
                ),
            )
        ).all()
    }
    published = (
        await session.execute(
            select(CalendarPublication.date, CalendarPublication.band)
            .where(
                CalendarPublication.date >= date_from,
                CalendarPublication.draft_snapshot.is_(None),
            )
            .order_by(CalendarPublication.date, CalendarPublication.band),
        )
    ).all()

    return [
        (row.date, row.band)
        for row in published
        if (row.date, row.band) not in confirmed
    ]


async def main(date_from: date, dry_run: bool) -> None:
    async with AsyncSessionLocal() as session:
        changed = 0

        for day, band in await _bands(session, date_from):
            before = await _shifts(session, day)
            lessons = await LessonRepository(session).list_for_band(day, band)

            await realign_shifts(session, day, band, lessons)

            after = await _shifts(session, day)

            for row in sorted(before - after):
                print(f"  - {row[0]} {band:<9} {row[1]} stanza {row[2]} {row[3]}")

            for row in sorted(after - before):
                print(f"  + {row[0]} {band:<9} {row[1]} stanza {row[2]} {row[3]}")

            changed += before != after

        print()
        print(f"{changed} fasce riallineate, dal {date_from.isoformat()} in poi.")

        if dry_run:
            await session.rollback()
            print("Prova a vuoto: niente è stato salvato.")
        else:
            await session.commit()
            print("Riallineamento salvato.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Riallinea i turni dei responsabili di stanza alle lezioni.",
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
