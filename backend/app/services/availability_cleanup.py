from __future__ import annotations

from collections.abc import Iterable, Sequence
from datetime import date
from typing import Final

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import time_band_label
from app.models.availability import Availability
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.opening_day import OpeningDay
from app.models.presence import Presence
from app.models.teacher_room_assignment import TeacherRoomAssignment

_PUBLISHED_DAY_CANNOT_BE_CLOSED_ERROR: Final[str] = (
    "Non puoi chiudere una giornata con il calendario pubblicato: riportalo in bozza "
    "prima {days}."
)


def _day_label(day: date, band: str) -> str:
    return f"{day.strftime('%d/%m/%Y')} ({time_band_label(band).lower()})"


async def _assert_no_settled_lessons(
    session: AsyncSession,
    lessons: Sequence[Lesson],
) -> None:
    if not lessons:
        return

    pairs = {(lesson.date, lesson.band) for lesson in lessons}

    stored = (
        await session.execute(
            select(CalendarPublication.date, CalendarPublication.band).where(
                CalendarPublication.date.in_({day for day, _ in pairs}),
                CalendarPublication.draft_snapshot.is_(None),
            ),
        )
    ).all()

    clashing = sorted(pairs & {(day, band) for day, band in stored})

    if clashing:
        raise ValueError(
            _PUBLISHED_DAY_CANNOT_BE_CLOSED_ERROR.format(
                days=", ".join(_day_label(day, band) for day, band in clashing),
            ),
        )


async def _drop_orphan_room_assignments(
    session: AsyncSession,
    dates: Sequence[date],
) -> None:
    assignments = (
        (
            await session.execute(
                select(TeacherRoomAssignment).where(
                    TeacherRoomAssignment.date.in_(dates),
                ),
            )
        )
        .scalars()
        .all()
    )

    if not assignments:
        return

    still_in_building = set(
        await session.scalars(
            select(Availability.teacher_tax_code)
            .join(Lesson, Lesson.availability_id == Availability.id)
            .where(
                Lesson.date.in_(dates),
                Lesson.teacher_mode == "presence",
            ),
        ),
    )

    for assignment in assignments:
        if assignment.teacher_tax_code not in still_in_building:
            await session.delete(assignment)

    await session.flush()


async def purge_availabilities_for_closed_days(
    session: AsyncSession,
    dates: Iterable[date],
    mode: str,
) -> int:
    unique_dates = sorted(set(dates))

    if not unique_dates:
        return 0

    open_dates = set(
        (
            await session.execute(
                select(OpeningDay.date)
                .where(
                    OpeningDay.date.in_(unique_dates),
                    OpeningDay.mode == mode,
                    OpeningDay.start_time.is_not(None),
                )
                .distinct()
            )
        )
        .scalars()
        .all()
    )

    closed_dates = [value for value in unique_dates if value not in open_dates]

    if not closed_dates:
        return 0

    lessons = (
        (
            await session.execute(
                select(Lesson).where(
                    Lesson.date.in_(closed_dates),
                    or_(Lesson.teacher_mode == mode, Lesson.mode == mode),
                ),
            )
        )
        .scalars()
        .all()
    )

    await _assert_no_settled_lessons(session, lessons)

    for lesson in lessons:
        await session.delete(lesson)

    await session.flush()

    availabilities = await session.execute(
        delete(Availability).where(
            Availability.date.in_(closed_dates),
            Availability.mode == mode,
        )
    )

    presences = (
        (
            await session.execute(
                select(Presence).where(
                    Presence.date.in_(closed_dates),
                    Presence.mode == mode,
                )
            )
        )
        .scalars()
        .all()
    )

    for presence in presences:
        await session.delete(presence)

    await session.flush()

    await _drop_orphan_room_assignments(session, closed_dates)

    return (availabilities.rowcount or 0) + len(presences)
