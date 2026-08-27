from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, time

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.opening_day import OpeningDay
from app.models.presence import Presence
from app.models.teacher_room_assignment import TeacherRoomAssignment

# Availabilities/presences left outside the new openings are deleted whole,
# never clipped, together with the lessons, bookings, and rooms built on them.


@dataclass(frozen=True)
class PurgedHours:
    availabilities: int = 0
    presences: int = 0
    lessons: int = 0

    def __bool__(self) -> bool:
        return bool(self.availabilities or self.presences or self.lessons)


def _merged(spans: list[tuple[time, time]]) -> list[tuple[time, time]]:
    merged: list[tuple[time, time]] = []

    for start, end in sorted(spans):
        # Touching spans merge: adjacent openings count as one stretch.
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))

            continue

        merged.append((start, end))

    return merged


async def _openings_by_day(
    session: AsyncSession,
    days: Sequence[date],
    mode: str,
) -> dict[date, list[tuple[time, time]]]:
    rows = (
        (
            await session.execute(
                select(OpeningDay).where(
                    OpeningDay.date.in_(days),
                    OpeningDay.mode == mode,
                    OpeningDay.start_time.is_not(None),
                ),
            )
        )
        .scalars()
        .all()
    )

    spans: dict[date, list[tuple[time, time]]] = {}

    for row in rows:
        if row.start_time is None or row.end_time is None:
            continue

        spans.setdefault(row.date, []).append((row.start_time, row.end_time))

    return {day: _merged(found) for day, found in spans.items()}


def _outside(
    openings: dict[date, list[tuple[time, time]]],
    day: date,
    start: time,
    end: time,
) -> bool:
    return not any(
        opens <= start and end <= closes for opens, closes in openings.get(day, [])
    )


async def _outside_rows(
    session: AsyncSession,
    model: type[Availability] | type[Presence],
    days: Sequence[date],
    mode: str,
    openings: dict[date, list[tuple[time, time]]],
) -> list[Availability] | list[Presence]:
    rows = (
        (
            await session.execute(
                select(model).where(model.date.in_(days), model.mode == mode),
            )
        )
        .scalars()
        .all()
    )

    return [
        row
        for row in rows
        if _outside(openings, row.date, row.start_time, row.end_time)
    ]


async def _lessons_standing_on(
    session: AsyncSession,
    availability_ids: set[int],
    presence_ids: set[int],
) -> Sequence[Lesson]:
    if not availability_ids and not presence_ids:
        return []

    taught_to_them = (
        select(LessonBooking.lesson_id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .where(Booking.presence_id.in_(presence_ids))
    )

    return (
        (
            await session.execute(
                select(Lesson).where(
                    or_(
                        Lesson.availability_id.in_(availability_ids),
                        Lesson.id.in_(taught_to_them),
                    ),
                ),
            )
        )
        .scalars()
        .all()
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


# Every hours write ends here; a fully closed day purges everything.
# Confirmation of the cost is calendar_hours_sync's responsibility, not this.
async def purge_hours_outside_openings(
    session: AsyncSession,
    dates: Iterable[date],
    mode: str,
) -> PurgedHours:
    unique_dates = sorted(set(dates))

    if not unique_dates:
        return PurgedHours()

    openings = await _openings_by_day(session, unique_dates, mode)

    availabilities = await _outside_rows(
        session,
        Availability,
        unique_dates,
        mode,
        openings,
    )
    presences = await _outside_rows(session, Presence, unique_dates, mode, openings)

    if not availabilities and not presences:
        return PurgedHours()

    touched = sorted(
        {row.date for row in availabilities} | {row.date for row in presences},
    )

    lessons = await _lessons_standing_on(
        session,
        {row.id for row in availabilities},
        {row.id for row in presences},
    )

    for lesson in lessons:
        await session.delete(lesson)

    await session.flush()

    for availability in availabilities:
        await session.delete(availability)

    # Bookings cascade with their presence.
    for presence in presences:
        await session.delete(presence)

    await session.flush()

    await _drop_orphan_room_assignments(session, touched)

    return PurgedHours(
        availabilities=len(availabilities),
        presences=len(presences),
        lessons=len(lessons),
    )
