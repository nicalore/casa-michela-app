from datetime import datetime, time, timedelta
from typing import Final

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import week_unlocks_at
from app.models.notification import Notification, NotificationKindEnum
from app.models.opening_day import OpeningDay
from app.services.notification_kinds import holds_kind
from app.services.notifications import notify, reachable_identities
from app.services.push import PushBatch, joined

_TITLES: Final[dict[NotificationKindEnum, str]] = {
    NotificationKindEnum.AVAILABILITY_OPENED: (
        "Da adesso è possibile inserire le disponibilità per la settimana prossima"
    ),
    NotificationKindEnum.BOOKINGS_OPENED: (
        "Da adesso è possibile prenotare le lezioni per la settimana prossima"
    ),
}
_BODY: Final[str] = "Tocca per inserirle"
_WEB_BODY: Final[str] = "Clicca per inserirle"

_WEEK: Final[timedelta] = timedelta(days=7)

# "Da adesso" holds near 20:00 only: a server down longer lets that Friday go.
_LATE: Final[timedelta] = timedelta(hours=1)


async def _has_open_day(db: AsyncSession, monday: datetime) -> bool:
    return bool(
        await db.scalar(
            select(
                exists().where(
                    OpeningDay.date >= monday.date(),
                    OpeningDay.date < (monday + _WEEK).date(),
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


# Friday at 20:00: next week opens; gone on its Monday, when it is this week.
async def announce_opened_week(db: AsyncSession, now: datetime) -> PushBatch:
    monday = now.date() - timedelta(days=now.weekday()) + _WEEK
    opens = week_unlocks_at(monday)
    ends = datetime.combine(monday, time(0), tzinfo=opens.tzinfo)

    if not opens <= now < opens + _LATE or not await _has_open_day(db, ends):
        return joined([])

    kinds = [kind for kind in _TITLES if not await _told(db, kind, ends)]

    if not kinds:
        return joined([])

    accounts = await reachable_identities(db)

    return joined(
        [
            await notify(
                db,
                [
                    account.tax_code
                    for account in accounts
                    if holds_kind(account, kind)
                ],
                kind=kind,
                title=_TITLES[kind],
                body=_BODY,
                web_body=_WEB_BODY,
                expires_at=ends,
            )
            for kind in kinds
        ]
    )
