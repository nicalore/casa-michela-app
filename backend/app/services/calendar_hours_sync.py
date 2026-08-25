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

# What a change of hours does to a calendar that has already gone out.
#
# The opening hours are the ground a calendar stands on. Move them and what was
# decided on the old ones is no longer a plan anybody can keep: the band goes
# back into bozza, with every lesson still in it, and whoever publishes it again
# is saying a second time that it holds. Take them away altogether and the
# calendar goes with them — there is no day left to plan, and what is left to
# say about that part of the day is that the association is closed.
#
# It is one rule and it is written once here, because there are five ways to
# change an opening — the weekly hours, an extraordinary opening, a closure, an
# edit of either, and going back to the standard — and a rule kept in five
# places is a rule that holds in four.

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

    # Una sola cosa, e una soltanto, vuole il singolare: due disponibilità sono
    # due, e una disponibilità più una prenotazione sono due cose.
    if purged.availabilities + purged.presences + purged.lessons == 1:
        return f"{listed} non rientra nei nuovi orari ed è stata eliminata."

    return f"{listed} non rientrano nei nuovi orari e sono state eliminate."


# A calendar this write would take something away from: the whole of it where
# the band is left with no hours at all, and the lessons of the mode being
# written where the band survives the other way and only they are cleared.
@dataclass(frozen=True)
class LostCalendar:
    day: date
    band: str
    whole: bool

    def said(self) -> str:
        return f"{self.day.strftime('%d/%m/%Y')} ({time_band_label(self.band).lower()})"


# Raised instead of writing, where a write would take a published calendar away
# and the caller has not said it knows.
#
# The whole of the work has been done by then and none of it is kept: the
# transaction is left unfinished and the session unwinds it, which is what makes
# the answer exact — it is not a guess at what would happen, it is what did.
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


# The opening of one band of one day: every stretch it is open for, whichever
# way it is open. Two of these being equal is what "the hours have not changed"
# means, and it is why the modes are in it — a morning that shut its screens and
# kept its doors is a morning that changed.
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

        # An hour outside the association's own day belongs to no band. It
        # cannot be written through the API, and a row that has one anyway is
        # not a reason to refuse a change of hours somewhere else.
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


# The lessons of a band: all of them, or only those given in the ways of being
# open named — a band that keeps its screens keeps the lessons taught on them.
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


# The hours as they stood before a write, held for as long as the write takes.
#
# Only the days that have a calendar are read: everywhere else there is nothing
# to keep in step, and a restore covering three months would otherwise weigh
# every day of them.
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

    # Done after the write and before it is kept. Where it finds a published
    # calendar the write would take something away from and the caller has not
    # said it knows, it refuses — and the refusal leaves the transaction
    # unfinished, so nothing of the write survives it.
    async def settle(
        self,
        *,
        confirmed: bool = False,
        purged: PurgedHours | None = None,
    ) -> None:
        # The hours taken away are asked about too, calendar or no calendar:
        # they were somebody's offer and somebody's booking, and they are gone
        # either way. One question covers both, and it is the same refusal.
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
                # The band has no hours left at all: there is nothing to hold a
                # calendar up any more, and nothing left of that part of the day
                # to say beyond that the association is closed.
                await _drop_band(self.session, publication.date, publication.band)
                await self.session.delete(publication)

                lost.append(LostCalendar(day=key[0], band=key[1], whole=True))

                continue

            if withdrawn:
                # One of the two ways of being open has gone. What was sent out
                # was a day in both, and it cannot be sent again by leaving a
                # bozza: the band goes back to never having been published, and
                # the lessons given the way that shut go with it.
                await _drop_band(
                    self.session,
                    publication.date,
                    publication.band,
                    modes=withdrawn,
                )
                await self.session.delete(publication)

                lost.append(LostCalendar(day=key[0], band=key[1], whole=False))

                continue

            # The hours only moved: the calendar goes back to being worked on,
            # and nothing in it is lost — leaving the bozza puts it back exactly
            # as it was sent.
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

    # A band left holding fewer lessons than it was published with, by some
    # other road than the two above — the day shutting in a mode clears the
    # lessons given in it wherever they stand. What went out is not what is
    # there any more, so that calendar goes back to never having been sent.
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
