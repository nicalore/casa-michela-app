from collections import defaultdict
from datetime import date, datetime, time, timedelta
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import TimeBandEnum
from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.notification import Notification, NotificationKindEnum
from app.services.notifications import notify, reachable_identities, withdraw
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_TITLE: Final[str] = (
    "Ricordati di indossare il braccialetto e di timbrare l'entrata e l'uscita"
)
_BODY: Final[str] = "Buon lavoro!"

_AHEAD: Final[timedelta] = timedelta(minutes=30)

_PRESENCE: Final[str] = "presence"

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.ARRIVAL_REMINDER

# A band's in-presence convocation: from its first start to its last end.
Call = tuple[TimeBandEnum, time, time]


async def _calls(db: AsyncSession, day: date) -> dict[str, list[Call]]:
    published = select(CalendarPublication.band).where(
        CalendarPublication.date == day,
    )
    lessons = (
        select(
            Availability.teacher_tax_code,
            Lesson.band,
            Lesson.start_time,
            Lesson.end_time,
        )
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(
            Lesson.date == day,
            Lesson.teacher_mode == _PRESENCE,
            Lesson.band.in_(published),
        )
    )
    activities = (
        select(
            Availability.teacher_tax_code,
            CalendarActivity.band,
            CalendarActivity.start_time,
            CalendarActivity.end_time,
        )
        .join(Availability, Availability.id == CalendarActivity.availability_id)
        .where(
            CalendarActivity.date == day,
            CalendarActivity.teacher_mode == _PRESENCE,
            CalendarActivity.start_time.is_not(None),
            CalendarActivity.band.in_(published),
        )
    )
    spans: dict[tuple[str, str], list[tuple[time, time]]] = defaultdict(list)

    for teacher, band, start, end in await db.execute(lessons.union_all(activities)):
        spans[(teacher, band)].append((start, end))

    calls: dict[str, list[Call]] = defaultdict(list)

    for (teacher, band), rows in spans.items():
        calls[teacher].append(
            (
                TimeBandEnum(band),
                min(start for start, _ in rows),
                max(end for _, end in rows),
            )
        )

    return calls


def _gap(end: time, start: time) -> timedelta:
    return datetime.combine(date.min, start) - datetime.combine(date.min, end)


# Still in the building from the call before: that one's reminder covers it.
def _arrivals(calls: list[Call]) -> list[Call]:
    ordered = sorted(calls, key=lambda call: call[1])

    return [
        call
        for previous, call in zip([None, *ordered], ordered, strict=False)
        if previous is None or _gap(previous[2], call[1]) >= _AHEAD
    ]


async def _teachers(db: AsyncSession) -> set[str]:
    return {
        account.tax_code
        for account in await reachable_identities(db)
        if "TEACHER" in RoleService.get_available_roles(account.person)
    }


# Half an hour before each arrival, once per teacher and band; gone at its start.
async def remind_arrivals(db: AsyncSession, now: datetime) -> PushBatch:
    day = now.date()
    arrivals = {
        (teacher, band): datetime.combine(day, start, tzinfo=now.tzinfo)
        for teacher, own in (await _calls(db, day)).items()
        for band, start, _ in _arrivals(own)
    }
    rows = await db.execute(
        select(
            Notification.account_tax_code,
            Notification.calendar_band,
            Notification.withdrawn_at.is_(None),
        ).where(
            Notification.kind == _KIND,
            Notification.calendar_date == day,
        )
    )
    told = {(code, TimeBandEnum(band)): live for code, band, live in rows}
    batches: list[PushBatch] = []

    # A calendar changed since: no longer called in presence then, no reminder.
    for teacher, band in [key for key, live in told.items() if live]:
        if (teacher, band) not in arrivals:
            batches.append(
                await withdraw(
                    db,
                    kinds=[_KIND],
                    calendar=(day, band),
                    owners=[teacher],
                )
            )

    due = {
        key: starts_at
        for key, starts_at in arrivals.items()
        if key not in told and starts_at - _AHEAD <= now < starts_at
    }
    teachers = await _teachers(db) if due else set()

    for (teacher, band), starts_at in due.items():
        if teacher in teachers:
            batches.append(
                await notify(
                    db,
                    [teacher],
                    kind=_KIND,
                    title=_TITLE,
                    body=_BODY,
                    calendar=(day, band),
                    expires_at=starts_at,
                )
            )

    return joined(batches)
