from __future__ import annotations

from collections.abc import Iterable, Iterator, Sequence
from dataclasses import dataclass
from datetime import date, time, timedelta
from typing import Final

from app.core.holidays import holidays_for_year
from app.models.opening_day import OpeningDay
from app.models.weekly_template import WeeklyTemplate
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository

_MODES: Final[tuple[str, ...]] = ("presence", "online")

_INVALID_RANGE_ERROR: Final[str] = (
    "end_date deve essere successiva o uguale a start_date."
)

# What identifies a row within a day: an all-day closure has no start time.
_SlotKey = tuple[date, str, time | None]


@dataclass(frozen=True)
class GenerationResult:
    dates_processed: int
    rows_created: int
    rows_skipped_existing: int


def _dates_between(start_date: date, end_date: date) -> Iterator[date]:
    current = start_date

    while current <= end_date:
        yield current
        current += timedelta(days=1)


def _closure_rows(day: date, label: str) -> Iterator[tuple[_SlotKey, OpeningDay]]:
    for mode in _MODES:
        yield (
            (day, mode, None),
            OpeningDay(
                date=day,
                mode=mode,
                start_time=None,
                end_time=None,
                is_override=True,
                note=label,
            ),
        )


# Modes are independent: no hour inheritance between them.
def _template_rows(
    day: date,
    templates: Sequence[WeeklyTemplate],
) -> Iterator[tuple[_SlotKey, OpeningDay]]:
    for template in templates:
        if template.effective_from > day:
            continue

        yield (
            (day, template.mode, template.start_time),
            OpeningDay(
                date=day,
                mode=template.mode,
                start_time=template.start_time,
                end_time=template.end_time,
                is_override=False,
            ),
        )


# Script-only, never imported by an API router, so these cannot be exposed
# by mistake.
class OpeningDayGenerationService:
    def __init__(
        self,
        opening_day_repository: OpeningDayRepository,
        weekly_template_repository: WeeklyTemplateRepository,
    ) -> None:
        self.opening_day_repository = opening_day_repository
        self.weekly_template_repository = weekly_template_repository

    async def _persist(self, opening_days: Sequence[OpeningDay]) -> None:
        await self.opening_day_repository.create_many(opening_days)
        await self.opening_day_repository.commit()

    async def seed_holidays(self, year: int) -> list[OpeningDay]:
        existing = await self.opening_day_repository.existing_slot_keys(
            date(year, 1, 1),
            date(year, 12, 31),
        )
        holidays = holidays_for_year(year)

        to_create = [
            opening_day
            for holiday_date, label in holidays.items()
            for key, opening_day in _closure_rows(holiday_date, label)
            if key not in existing
        ]

        await self._persist(to_create)

        return to_create

    async def generate_opening_days(
        self,
        start_date: date,
        end_date: date,
    ) -> GenerationResult:
        if end_date < start_date:
            raise ValueError(_INVALID_RANGE_ERROR)

        existing = await self.opening_day_repository.existing_slot_keys(
            start_date,
            end_date,
        )
        templates_by_weekday = {
            weekday: await self.weekly_template_repository.list_by_weekday(weekday)
            for weekday in range(1, 8)
        }

        holidays_by_year: dict[int, dict[date, str]] = {}
        to_create: list[OpeningDay] = []
        rows_skipped = 0
        dates_processed = 0

        for current in _dates_between(start_date, end_date):
            dates_processed += 1

            if current.year not in holidays_by_year:
                holidays_by_year[current.year] = holidays_for_year(current.year)

            label = holidays_by_year[current.year].get(current)

            # A holiday closes the day in both modes; weekday hours do not apply.
            candidates: Iterable[tuple[_SlotKey, OpeningDay]] = (
                _closure_rows(current, label)
                if label is not None
                else _template_rows(current, templates_by_weekday[current.isoweekday()])
            )

            for key, opening_day in candidates:
                if key in existing:
                    rows_skipped += 1
                    continue

                to_create.append(opening_day)
                existing.add(key)

        await self._persist(to_create)

        return GenerationResult(
            dates_processed=dates_processed,
            rows_created=len(to_create),
            rows_skipped_existing=rows_skipped,
        )
