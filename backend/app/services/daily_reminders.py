from collections import defaultdict
from collections.abc import Sequence
from datetime import date, datetime, time, timedelta
from typing import Final
from zoneinfo import ZoneInfo

from sqlalchemy import exists, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.availability import Availability
from app.models.notification import Notification, NotificationKindEnum
from app.models.opening_day import OpeningDay
from app.models.parental_responsibility import ParentalResponsibility
from app.models.presence import Presence
from app.services.notification_kinds import books_alone, holds_kind
from app.services.notifications import dismissals, notify, reachable_identities
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_ROME: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_AVAILABILITY: Final[NotificationKindEnum] = NotificationKindEnum.AVAILABILITY_REMINDER
_BOOKING: Final[NotificationKindEnum] = NotificationKindEnum.BOOKING_REMINDER

_AVAILABILITY_TITLE: Final[str] = "Non hai dato alcuna disponibilità per domani"
_BOOKING_TITLE: Final[str] = "Non hai prenotato alcuna lezione per domani"
_NAMED_TITLE: Final[str] = "{names} non {verb} alcuna lezione prenotata per domani"
_BODY: Final[str] = "Tocca per inserirne una"
_WEB_BODY: Final[str] = "Clicca per inserirne una"

_AT: Final[time] = time(19)

# A server down longer lets that evening go rather than remind at any hour.
_LATE: Final[timedelta] = timedelta(hours=1)


# The day a reminder is about starts at the midnight it expires at.
def _midnight(day: date) -> datetime:
    return datetime.combine(day, time(0), tzinfo=_ROME)


async def _is_open(db: AsyncSession, day: date) -> bool:
    return bool(
        await db.scalar(
            select(
                exists().where(
                    OpeningDay.date == day,
                    OpeningDay.start_time.is_not(None),
                )
            )
        )
    )


async def _told(db: AsyncSession, kind: NotificationKindEnum, ends: datetime) -> bool:
    return bool(
        await db.scalar(
            select(
                exists().where(
                    Notification.kind == kind,
                    Notification.expires_at == ends,
                )
            )
        )
    )


def _named(names: list[str]) -> str:
    if len(names) == 1:
        return names[0]

    return f"{', '.join(names[:-1])} e {names[-1]}"


# A parent's children by name; a pupil booking alone stands for themself.
def _pupils_of(account: Account) -> dict[str, str]:
    person = account.person
    children = RoleService.pupil_children_tax_codes(person)

    if children:
        return {
            row.child_tax_code: row.child.first_name
            for row in person.parent_profile.children_relationships
            if row.child_tax_code in children
        }

    return {account.tax_code: person.first_name} if books_alone(account) else {}


# Nothing booked for any of their pupils, or only for some, who are named.
def _family_title(account: Account, booked: set[str]) -> str | None:
    pupils = _pupils_of(account)
    waiting = sorted(name for code, name in pupils.items() if code not in booked)

    if not waiting:
        return None

    if len(waiting) == len(pupils):
        return _BOOKING_TITLE

    return _NAMED_TITLE.format(
        names=_named(waiting),
        verb="ha" if len(waiting) == 1 else "hanno",
    )


# Every evening at 19:00, for tomorrow if open: who has given or booked nothing yet.
async def remind_tomorrow(db: AsyncSession, now: datetime) -> PushBatch:
    starts = datetime.combine(now.date(), _AT, tzinfo=now.tzinfo)
    tomorrow = now.date() + timedelta(days=1)
    ends = _midnight(tomorrow)

    if not starts <= now < starts + _LATE or not await _is_open(db, tomorrow):
        return joined([])

    kinds = [
        kind for kind in (_AVAILABILITY, _BOOKING) if not await _told(db, kind, ends)
    ]

    if not kinds:
        return joined([])

    accounts = await reachable_identities(db)
    batches: list[PushBatch] = []

    if _AVAILABILITY in kinds:
        given = set(
            await db.scalars(
                select(Availability.teacher_tax_code).where(
                    Availability.date == tomorrow,
                )
            )
        )
        batches.append(
            await notify(
                db,
                [
                    account.tax_code
                    for account in accounts
                    if holds_kind(account, _AVAILABILITY)
                    and account.tax_code not in given
                ],
                kind=_AVAILABILITY,
                title=_AVAILABILITY_TITLE,
                body=_BODY,
                web_body=_WEB_BODY,
                expires_at=ends,
            )
        )

    if _BOOKING in kinds:
        booked = set(
            await db.scalars(
                select(Presence.student_tax_code).where(Presence.date == tomorrow)
            )
        )
        groups: dict[str, list[str]] = defaultdict(list)

        for account in accounts:
            if not holds_kind(account, _BOOKING):
                continue

            title = _family_title(account, booked)

            if title is not None:
                groups[title].append(account.tax_code)

        for title, codes in groups.items():
            batches.append(
                await notify(
                    db,
                    codes,
                    kind=_BOOKING,
                    title=title,
                    body=_BODY,
                    web_body=_WEB_BODY,
                    expires_at=ends,
                )
            )

    return joined(batches)


async def _settle(
    db: AsyncSession,
    kind: NotificationKindEnum,
    day: date,
    owners: Sequence[str],
) -> PushBatch:
    notifications = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == kind,
                Notification.expires_at == _midnight(day),
                Notification.withdrawn_at.is_(None),
                Notification.account_tax_code.in_(list(owners)),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

    return await dismissals(db, [row for row in notifications if row.read_at is None])


# Given for that day: its reminder has done its work.
async def availability_given(
    db: AsyncSession,
    teacher_tax_code: str,
    day: date,
) -> PushBatch:
    return await _settle(db, _AVAILABILITY, day, [teacher_tax_code])


# Booked for that day, even for one child only: the pupil's and the parents' go.
async def presence_booked(
    db: AsyncSession,
    student_tax_code: str,
    day: date,
) -> PushBatch:
    parents = await db.scalars(
        select(ParentalResponsibility.parent_tax_code).where(
            ParentalResponsibility.child_tax_code == student_tax_code,
        )
    )

    return await _settle(db, _BOOKING, day, [student_tax_code, *parents])
