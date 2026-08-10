from datetime import date, time, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.core.holidays import holiday_label, holidays_for_year
from app.models.opening_day import OpeningDay
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.weekly_template import WeeklyTemplateCreate
from app.services.calendar_bootstrap import bootstrap_calendar, calendar_horizon
from app.services.weekly_template_service import WeeklyTemplateService

_MORNING = (time(9, 0), time(12, 0))


# The first occurrence of that weekday which is not a public holiday: on a
# holiday the calendar says closed whatever the templates say, and the day would
# prove nothing about propagation.
def _first_open_occurrence(from_day: date, weekday: int) -> date:
    day = from_day + timedelta(days=(weekday - from_day.isoweekday()) % 7)

    while holiday_label(day) is not None:
        day += timedelta(days=7)

    return day


def _templates(db: AsyncSession) -> WeeklyTemplateService:
    return WeeklyTemplateService(
        WeeklyTemplateRepository(db),
        OpeningDayRepository(db),
    )


async def _add_morning_band(
    db: AsyncSession, weekday: int, effective_from: date
) -> None:
    await _templates(db).create(
        WeeklyTemplateCreate(
            weekday=weekday,
            mode=OpeningModeEnum.PRESENCE,
            start_time=_MORNING[0],
            end_time=_MORNING[1],
            effective_from=effective_from,
        )
    )


async def _rows_on(db: AsyncSession, day: date, mode: str) -> list[OpeningDay]:
    return list(
        (
            await db.execute(
                select(OpeningDay).where(
                    OpeningDay.date == day,
                    OpeningDay.mode == mode,
                )
            )
        )
        .scalars()
        .all()
    )


# The state the migrations leave behind: weekly templates seeded, calendar
# empty. Everything that propagates the standard hours is bounded by the last
# materialised date, so a calendar that was never generated is one where saving
# the hours writes the template and reaches no day at all.
async def test_an_empty_calendar_is_materialised_to_the_horizon(
    db: AsyncSession,
) -> None:
    today = today_in_rome()

    result = await bootstrap_calendar(db)

    assert result is not None
    assert result.rows_created > 0

    for mode in ("presence", "online"):
        materialised = (
            (await db.execute(select(OpeningDay.date).where(OpeningDay.mode == mode)))
            .scalars()
            .all()
        )

        assert min(materialised) >= today
        assert max(materialised) <= calendar_horizon(today)


# What the bootstrap is for. Propagation of the standard hours stops at the last
# materialised date by design — beyond it the days do not exist and inventing
# them would be generation — so on a calendar that was never generated the hours
# are saved as a template, reported as saved, and reach no day at all.
async def test_without_a_calendar_the_standard_hours_reach_no_day(
    db: AsyncSession,
) -> None:
    today = today_in_rome()
    wednesday = _first_open_occurrence(today, 3)

    await _add_morning_band(db, weekday=3, effective_from=today)

    assert await _rows_on(db, wednesday, "presence") == []


async def test_with_a_calendar_the_standard_hours_reach_the_days(
    db: AsyncSession,
) -> None:
    today = today_in_rome()
    wednesday = _first_open_occurrence(today, 3)

    await bootstrap_calendar(db)
    await _add_morning_band(db, weekday=3, effective_from=today)

    rows = await _rows_on(db, wednesday, "presence")

    assert _MORNING in [(row.start_time, row.end_time) for row in rows]


# The bootstrap is not a second way of generating the calendar: once there is
# one, it stands aside.
async def test_a_calendar_that_reaches_today_is_left_alone(db: AsyncSession) -> None:
    await bootstrap_calendar(db)

    before = (
        (await db.execute(select(OpeningDay.id).order_by(OpeningDay.id)))
        .scalars()
        .all()
    )

    assert await bootstrap_calendar(db) is None

    after = (
        (await db.execute(select(OpeningDay.id).order_by(OpeningDay.id)))
        .scalars()
        .all()
    )

    assert after == before


# Generating from the templates alone would open the association on Christmas.
async def test_holidays_come_out_closed(db: AsyncSession) -> None:
    today = today_in_rome()
    horizon = calendar_horizon(today)

    await bootstrap_calendar(db)

    upcoming = [
        holiday
        for holiday in holidays_for_year(today.year)
        if today <= holiday <= horizon
    ]

    assert upcoming, "nessuna festività nell'orizzonte: il test non prova nulla"

    for holiday in upcoming:
        rows = await _rows_on(db, holiday, "presence")

        assert [(row.start_time, row.end_time, row.is_override) for row in rows] == [
            (None, None, True)
        ]


# A calendar left behind by time is as unusable as one never generated: nothing
# can be propagated into a horizon that has already passed.
async def test_a_calendar_stopping_in_the_past_is_generated_again(
    db: AsyncSession,
) -> None:
    yesterday = today_in_rome() - timedelta(days=1)

    for mode in ("presence", "online"):
        db.add(
            OpeningDay(
                date=yesterday,
                mode=mode,
                start_time=None,
                end_time=None,
                is_override=True,
                note="Chiusura",
            )
        )

    await db.flush()

    result = await bootstrap_calendar(db)

    assert result is not None
    assert result.rows_created > 0
