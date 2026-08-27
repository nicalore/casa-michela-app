from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import time_band_label
from app.core.time_band import DAY_END, DAY_START, band_of
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.opening_day import OpeningDay
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.services.availability_cleanup import PurgedHours
from app.services.calendar_snapshot import snapshot_of

# Single rule, written once, for what a change of opening hours does to a
# published calendar: moved hours send the band back to draft; removed hours delete it.

_LOST_ERROR: Final[str] = "write_would_take_away"

_ONE_LOST: Final[str] = (
    "Il calendario del {days} è pubblicato. Salvando, le lezioni che docenti, "
    "studenti e genitori hanno già ricevuto vengono eliminate."
)

_MANY_LOST: Final[str] = (
    "I calendari del {days} sono pubblicati. Salvando, le lezioni che docenti, "
    "studenti e genitori hanno già ricevuto vengono eliminate."
)


def _counted(value: int, singular: str, plural: str) -> str:
    return f"{value} {singular if value == 1 else plural}"


def _hours_said(purged: PurgedHours) -> str:
    parts = [
        _counted(purged.availabilities, "disponibilità", "disponibilità"),
        _counted(purged.presences, "prenotazione", "prenotazioni"),
        _counted(purged.lessons, "lezione", "lezioni"),
    ]

    said = [
        part
        for part, value in zip(
            parts,
            (purged.availabilities, purged.presences, purged.lessons),
            strict=True,
        )
        if value
    ]

    listed = " e ".join([", ".join(said[:-1]), said[-1]]) if len(said) > 1 else said[0]

    if purged.availabilities + purged.presences + purged.lessons == 1:
        return f"{listed} non rientra nei nuovi orari ed è stata eliminata."

    return f"{listed} non rientrano nei nuovi orari e sono state eliminate."


# whole=True when the band lost all its hours; False when only one mode's lessons go.
@dataclass(frozen=True)
class LostCalendar:
    day: date
    band: str
    whole: bool

    def said(self) -> str:
        return f"{self.day.strftime('%d/%m/%Y')} ({time_band_label(self.band).lower()})"


# Raised after the write is done but before commit; the rollback undoes it,
# which is what makes the reported losses exact.
class WriteWouldTakeAway(HTTPException):
    def __init__(
        self,
        lost: Sequence[LostCalendar] = (),
        purged: PurgedHours | None = None,
    ) -> None:
        said = []

        if lost:
            pattern = _ONE_LOST if len(lost) == 1 else _MANY_LOST
            said.append(pattern.format(days=", ".join(row.said() for row in lost)))

        if purged:
            said.append(_hours_said(purged))

        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": _LOST_ERROR,
                "message": " ".join(said),
                "lost": [
                    {
                        "date": row.day.isoformat(),
                        "band": row.band,
                        "whole": row.whole,
                    }
                    for row in lost
                ],
                "hours": {
                    "availabilities": purged.availabilities if purged else 0,
                    "presences": purged.presences if purged else 0,
                    "lessons": purged.lessons if purged else 0,
                },
            },
        )


# Modes are part of the key: a band that closed one mode has changed.
type BandOpening = frozenset[tuple[str, time, time]]

type OpeningsByBand = dict[tuple[date, str], BandOpening]


async def _days_with_a_calendar(
    session: AsyncSession,
    dates: Iterable[date],
) -> list[date]:
    unique = sorted(set(dates))

    if not unique:
        return []

    return sorted(
        set(
            (
                await session.execute(
                    select(CalendarPublication.date).where(
                        CalendarPublication.date.in_(unique),
                    ),
                )
            )
            .scalars()
            .all(),
        ),
    )


async def _publications_of(
    session: AsyncSession,
    days: Sequence[date],
) -> Sequence[CalendarPublication]:
    return (
        (
            await session.execute(
                select(CalendarPublication).where(
                    CalendarPublication.date.in_(days),
                ),
            )
        )
        .scalars()
        .all()
    )


async def _openings_of(
    session: AsyncSession,
    days: Sequence[date],
) -> OpeningsByBand:
    if not days:
        return {}

    rows = (
        (
            await session.execute(
                select(OpeningDay).where(
                    OpeningDay.date.in_(days),
                    OpeningDay.start_time.is_not(None),
                ),
            )
        )
        .scalars()
        .all()
    )

    openings: OpeningsByBand = {}

    for row in rows:
        start = row.start_time
        end = row.end_time

        # Hours outside the association's day belong to no band; ignore stray rows.
        if start is None or end is None or start < DAY_START or start >= DAY_END:
            continue

        key = (row.date, str(band_of(start)))
        openings[key] = openings.get(key, frozenset()) | {(row.mode, start, end)}

    return openings


async def _picture_of(session: AsyncSession, day: date, band: str) -> dict:
    return snapshot_of(
        await LessonRepository(session).list_for_band(day, band),
        await TeacherRoomAssignmentRepository(session).list_for_day(day),
        await RoomSupervisionRepository(session).list_for_day(day),
    )


def _modes_of(opening: BandOpening | None) -> set[str]:
    return {mode for mode, _, _ in opening or frozenset()}


# Deletes the band's lessons: all of them, or only those in the given modes.
async def _drop_band(
    session: AsyncSession,
    day: date,
    band: str,
    *,
    modes: set[str] | None = None,
) -> None:
    lessons = (
        (
            await session.execute(
                select(Lesson).where(
                    Lesson.date == day,
                    Lesson.band == band,
                    *(
                        []
                        if modes is None
                        else [
                            or_(
                                Lesson.teacher_mode.in_(modes),
                                Lesson.mode.in_(modes),
                            ),
                        ]
                    ),
                ),
            )
        )
        .scalars()
        .all()
    )

    for lesson in lessons:
        await session.delete(lesson)

    await session.flush()


async def _lessons_by_band(
    session: AsyncSession,
    days: Sequence[date],
) -> dict[tuple[date, str], int]:
    if not days:
        return {}

    rows = await session.execute(
        select(Lesson.date, Lesson.band, func.count())
        .where(Lesson.date.in_(days))
        .group_by(Lesson.date, Lesson.band),
    )

    return {(day, band): count for day, band, count in rows.all()}


# Captures the hours before a write; only days with a calendar are read.
class CalendarHoursWatch:
    def __init__(
        self,
        session: AsyncSession,
        days: Sequence[date],
        before: OpeningsByBand,
        lessons: dict[tuple[date, str], int],
    ) -> None:
        self.session = session
        self.days = days
        self.before = before
        self.lessons = lessons

    @classmethod
    async def taken(
        cls,
        session: AsyncSession,
        dates: Iterable[date],
    ) -> CalendarHoursWatch:
        days = await _days_with_a_calendar(session, dates)

        return cls(
            session,
            days,
            await _openings_of(session, days),
            await _lessons_by_band(session, days),
        )

    # Call after the write, before commit; a refusal leaves the transaction to roll back.
    async def settle(
        self,
        *,
        confirmed: bool = False,
        purged: PurgedHours | None = None,
    ) -> None:
        if not self.days:
            if purged and not confirmed:
                raise WriteWouldTakeAway(purged=purged)

            return

        after = await _openings_of(self.session, self.days)
        lost: list[LostCalendar] = []

        for publication in await _publications_of(self.session, self.days):
            key = (publication.date, publication.band)

            if self.before.get(key) == after.get(key):
                continue

            withdrawn = _modes_of(self.before.get(key)) - _modes_of(after.get(key))

            if not after.get(key):
                await _drop_band(self.session, publication.date, publication.band)
                await self.session.delete(publication)

                lost.append(LostCalendar(day=key[0], band=key[1], whole=True))

                continue

            if withdrawn:
                # A mode was withdrawn: unpublish and drop only that mode's lessons.
                await _drop_band(
                    self.session,
                    publication.date,
                    publication.band,
                    modes=withdrawn,
                )
                await self.session.delete(publication)

                lost.append(LostCalendar(day=key[0], band=key[1], whole=False))

                continue

            # Hours only moved: back to draft, nothing lost.
            if publication.draft_snapshot is None:
                publication.draft_snapshot = await _picture_of(
                    self.session,
                    publication.date,
                    publication.band,
                )

        await self.session.flush()

        lost.extend(await self._emptied(exclude={(row.day, row.band) for row in lost}))

        if (lost or purged) and not confirmed:
            raise WriteWouldTakeAway(
                sorted(lost, key=lambda row: (row.day, row.band)),
                purged,
            )

    # Unpublishes bands whose lesson count dropped through side effects not caught above.
    async def _emptied(
        self,
        *,
        exclude: set[tuple[date, str]],
    ) -> list[LostCalendar]:
        after = await _lessons_by_band(self.session, self.days)
        emptied: list[LostCalendar] = []

        for publication in await _publications_of(self.session, self.days):
            key = (publication.date, publication.band)

            if key in exclude or after.get(key, 0) >= self.lessons.get(key, 0):
                continue

            await self.session.delete(publication)

            emptied.append(LostCalendar(day=key[0], band=key[1], whole=False))

        await self.session.flush()

        return emptied
