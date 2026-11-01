from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import band_of
from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.lesson import Lesson
from app.services.lesson_guard import find_settled_bands

_PRESENCE: Final[str] = "presence"
_ONLINE: Final[str] = "online"

_CALLED_IN_ERROR: Final[str] = (
    "Il docente è convocato in presenza ({hours}): non può collegarsi da casa."
)

_CALLED_ONLINE_ERROR: Final[str] = (
    "Il docente è convocato online: "
    "ha lezioni che non rientrano nella sua disponibilità in presenza."
)


# One lesson or activity of a teacher's band, as the band's mode sees it.
@dataclass(frozen=True)
class BandHour:
    start_time: time
    end_time: time
    # A pupil in the building, or an activity: only hours offered in presence hold it.
    in_person: bool = False


def _covering(
    offered: Iterable[Availability],
    mode: str,
    start_time: time,
    end_time: time,
) -> Availability | None:
    return next(
        (
            slot
            for slot in offered
            if slot.mode == mode
            and slot.start_time <= start_time
            and slot.end_time >= end_time
        ),
        None,
    )


# A teacher is called in or online for a whole band, never both. In person as soon as
# a pupil is in the building or an activity is given; else online, on the hours
# offered online; else in, on the hours offered there. None: no single mode holds
# every hour.
def band_mode(hours: Sequence[BandHour], offered: Sequence[Availability]) -> str | None:
    def holds(mode: str) -> bool:
        return all(
            (mode == _PRESENCE or not hour.in_person)
            and _covering(offered, mode, hour.start_time, hour.end_time) is not None
            for hour in hours
        )

    brought_in = any(hour.in_person for hour in hours)
    order = (_PRESENCE, _ONLINE) if brought_in else (_ONLINE, _PRESENCE)

    return next((mode for mode in order if holds(mode)), None)


def _lesson_hour(lesson: Lesson) -> BandHour:
    return BandHour(
        lesson.start_time,
        lesson.end_time,
        in_person=lesson.mode == _PRESENCE,
    )


def _activity_hours(activities: Iterable[CalendarActivity]) -> list[BandHour]:
    # Given, so timed; only an activity waiting for a teacher has no hours.
    return [
        BandHour(activity.start_time, activity.end_time, in_person=True)
        for activity in activities
        if activity.start_time is not None and activity.end_time is not None
    ]


async def _band_of(
    session: AsyncSession,
    teacher_tax_code: str,
    day: date,
    band: str,
) -> tuple[list[Lesson], list[CalendarActivity]]:
    lessons = await session.scalars(
        select(Lesson)
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(
            Availability.teacher_tax_code == teacher_tax_code,
            Lesson.date == day,
            Lesson.band == band,
        ),
    )
    activities = await session.scalars(
        select(CalendarActivity)
        .join(Availability, Availability.id == CalendarActivity.availability_id)
        .where(
            Availability.teacher_tax_code == teacher_tax_code,
            CalendarActivity.date == day,
            CalendarActivity.band == band,
        ),
    )

    return list(lessons), list(activities)


async def _offered(
    session: AsyncSession,
    teacher_tax_code: str,
    day: date,
) -> list[Availability]:
    return list(
        await session.scalars(
            select(Availability).where(
                Availability.teacher_tax_code == teacher_tax_code,
                Availability.date == day,
            ),
        ),
    )


def _presence_hours(offered: Iterable[Availability], band: str) -> str:
    return ", ".join(
        f"{slot.start_time:%H:%M} - {slot.end_time:%H:%M}"
        for slot in sorted(offered, key=lambda slot: slot.start_time)
        if slot.mode == _PRESENCE and band_of(slot.start_time) == band
    )


# Refuses [hour] when the teacher's band could keep one mode without it but not with
# it. A band already mixed, from before the rule, is left as it was.
async def assert_one_mode(
    session: AsyncSession,
    teacher_tax_code: str,
    day: date,
    band: str,
    hour: BandHour,
    *,
    lesson_id: int | None = None,
    activity_id: int | None = None,
) -> None:
    if band in await find_settled_bands(session, day):
        return

    lessons, activities = await _band_of(session, teacher_tax_code, day, band)
    offered = await _offered(session, teacher_tax_code, day)

    others = [
        *(_lesson_hour(lesson) for lesson in lessons if lesson.id != lesson_id),
        *_activity_hours(a for a in activities if a.id != activity_id),
    ]
    before = band_mode(others, offered)

    if before is None or band_mode([*others, hour], offered) is not None:
        return

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=(
            _CALLED_IN_ERROR.format(hours=_presence_hours(offered, band))
            if before == _PRESENCE
            else _CALLED_ONLINE_ERROR
        ),
    )


# Puts every lesson and activity of the teacher's band on hours of the band's mode.
# A band no single mode holds, from before the rule, only has what fits moved.
# Published bands are left as their convocations said.
async def settle_teacher_band(
    session: AsyncSession,
    teacher_tax_code: str,
    day: date,
    band: str,
) -> None:
    if band in await find_settled_bands(session, day):
        return

    lessons, activities = await _band_of(session, teacher_tax_code, day, band)

    if not any(lesson.mode == _ONLINE for lesson in lessons) and not activities:
        return

    offered = await _offered(session, teacher_tax_code, day)
    hours = [*(_lesson_hour(lesson) for lesson in lessons), *_activity_hours(activities)]
    mode = band_mode(hours, offered) or (
        _PRESENCE if any(hour.in_person for hour in hours) else _ONLINE
    )

    for activity in activities:
        if activity.start_time is None or activity.end_time is None:
            continue

        target = _covering(offered, mode, activity.start_time, activity.end_time)

        if target is not None and activity.availability_id != target.id:
            activity.availability_id = target.id
            activity.teacher_mode = target.mode

    for lesson in lessons:
        if lesson.mode != _ONLINE:
            continue

        target = _covering(offered, mode, lesson.start_time, lesson.end_time)

        if target is not None and target.id != lesson.availability_id:
            lesson.availability = target

    await session.flush()


# Every band the teacher teaches in on [days], as after a change to their hours.
async def settle_teacher_days(
    session: AsyncSession,
    teacher_tax_code: str,
    days: Iterable[date],
) -> None:
    for day in dict.fromkeys(days):
        bands = await session.scalars(
            select(Lesson.band)
            .join(Availability, Availability.id == Lesson.availability_id)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                Lesson.date == day,
            )
            .distinct(),
        )

        for band in list(bands):
            await settle_teacher_band(session, teacher_tax_code, day, band)


# Online lessons an availability can no longer hold move to another of the teacher's
# that covers them, rather than being dropped, as long as the band keeps one mode;
# published bands keep their own rule. Returns the lessons still to drop.
async def rehome_online_lessons(
    session: AsyncSession,
    lessons: Sequence[Lesson],
    leaving: Availability,
) -> list[Lesson]:
    if not lessons:
        return []

    others = [
        slot
        for slot in await _offered(session, leaving.teacher_tax_code, leaving.date)
        if slot.id != leaving.id
    ]
    settled = await find_settled_bands(session, leaving.date)
    moving = {lesson.id for lesson in lessons}
    modes: dict[str, str | None] = {}
    dropped = []

    for lesson in lessons:
        if lesson.band not in modes:
            modes[lesson.band] = await _mode_after_leaving(
                session,
                leaving,
                lesson.band,
                moving,
                others,
            )

        mode = modes[lesson.band]
        home = next(
            (
                slot
                for slot in others
                if lesson.mode == _ONLINE
                and lesson.band not in settled
                and (mode is None or slot.mode == mode)
                and slot.start_time <= lesson.start_time
                and slot.end_time >= lesson.end_time
            ),
            None,
        )

        if home is None:
            dropped.append(lesson)
        else:
            lesson.availability = home

    await session.flush()

    return dropped


# The mode the band keeps once [moving] leave: the one of what stays, or, with nothing
# staying, one that holds every lesson on the move. None: no constraint.
async def _mode_after_leaving(
    session: AsyncSession,
    leaving: Availability,
    band: str,
    moving: set[int],
    others: Sequence[Availability],
) -> str | None:
    lessons, activities = await _band_of(
        session,
        leaving.teacher_tax_code,
        leaving.date,
        band,
    )
    staying = {
        *(lesson.teacher_mode for lesson in lessons if lesson.id not in moving),
        *(
            activity.teacher_mode
            for activity in activities
            if activity.availability_id != leaving.id
        ),
    }

    if staying:
        return staying.pop() if len(staying) == 1 else None

    return band_mode(
        [_lesson_hour(lesson) for lesson in lessons if lesson.id in moving],
        others,
    )
