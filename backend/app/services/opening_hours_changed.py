from datetime import date, datetime, time, timedelta
from typing import Final
from zoneinfo import ZoneInfo

from sqlalchemy import func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationKindEnum
from app.services.notification_kinds import holds_kind
from app.services.notifications import (
    Bilingual,
    dismissals,
    notify,
    reachable_identities,
)
from app.services.push import PushBatch, joined

_ROME: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.OPENING_HOURS_CHANGED

# The phone taps, the desktop clicks.
_DAY_TITLE: Final[Bilingual] = Bilingual(
    "C'è stata una modifica agli orari di apertura per il giorno {day}",
    "The opening hours for {day} have changed",
)
_SPAN_TITLE: Final[Bilingual] = Bilingual(
    "C'è stata una modifica agli orari di apertura per le giornate "
    "dal {first} al {last}",
    "The opening hours from {first} to {last} have changed",
)
_BODY: Final[Bilingual] = Bilingual("Tocca per leggerla", "Tap to read it")
_WEB_BODY: Final[Bilingual] = Bilingual("Clicca per leggerla", "Click to read it")


def _label(day: date) -> str:
    return day.strftime("%d/%m/%Y")


def _title(first: date, last: date) -> Bilingual:
    if first == last:
        return Bilingual(
            _DAY_TITLE.it.format(day=_label(first)),
            _DAY_TITLE.en.format(day=_label(first)),
        )

    return Bilingual(
        _SPAN_TITLE.it.format(first=_label(first), last=_label(last)),
        _SPAN_TITLE.en.format(first=_label(first), last=_label(last)),
    )


# What told of the same days before goes: the news is the latest change.
async def _replace(db: AsyncSession, first: date, ends: datetime) -> PushBatch:
    notifications = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.calendar_date == first,
                Notification.expires_at == ends,
                Notification.withdrawn_at.is_(None),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

    return await dismissals(db, [row for row in notifications if row.read_at is None])


# Everyone but who made the change; gone once its last day is over.
async def announce_hours_change(
    db: AsyncSession,
    first: date,
    last: date,
    *,
    author: str,
    today: date,
) -> PushBatch:
    if last < today:
        return joined([])

    ends = datetime.combine(last + timedelta(days=1), time(0), tzinfo=_ROME)
    replaced = await _replace(db, first, ends)
    recipients = [
        account.tax_code
        for account in await reachable_identities(db)
        if account.tax_code != author and holds_kind(account, _KIND)
    ]

    return joined(
        [
            replaced,
            await notify(
                db,
                recipients,
                kind=_KIND,
                title=_title(first, last),
                body=_BODY,
                web_body=_WEB_BODY,
                calendar=first,
                expires_at=ends,
            ),
        ]
    )
