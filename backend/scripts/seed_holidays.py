# Seeds the public holiday closures for one year onto opening_days: the fixed
# ones plus Easter and Easter Monday, computed with Gauss' algorithm.
#
#     python -m scripts.seed_holidays <anno>

import argparse
import asyncio

from app.db.session import AsyncSessionLocal
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.services.opening_day_generation_service import OpeningDayGenerationService


async def main(year: int) -> None:
    async with AsyncSessionLocal() as session:
        service = OpeningDayGenerationService(
            OpeningDayRepository(session),
            WeeklyTemplateRepository(session),
        )
        created = await service.seed_holidays(year)

    print(f"Festività {year}: create {len(created)} righe di chiusura.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed festività su opening_days")
    parser.add_argument("year", type=int, help="Anno per cui seminare le festività")
    args = parser.parse_args()

    asyncio.run(main(args.year))
