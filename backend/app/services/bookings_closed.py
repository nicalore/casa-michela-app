from datetime import date, datetime, timedelta
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_close import band_ends_at, has_closed
from app.core.labels import time_band_phrase
from app.core.time_band import TimeBandEnum, band_of
from app.models.calendar_publication import CalendarPublication
from app.models.notification import Notification, NotificationKindEnum
from app.repositories.presence_repository import PresenceRepository
from app.services.notifications import notify, reachable_administrators
from app.services.push import PushBatch, joined

# The first sentence as the title.
_TITLE: Final[str] = "Le prenotazioni {band} sono chiuse"
_BODY: Final[str] = "Da adesso è possibile pubblicare il calendario"

# Closed but not over yet: a close missed while the server was down still counts.
def _closed_bands(now: datetime) -> list[tuple[date, TimeBandEnum]]:
    return [
        (day, band)
        for day in (now.date(), now.date() + timedelta(days=1))
        for band in TimeBandEnum
        if has_closed(day, band, now) and now < band_ends_at(day, band)
    ]


# Tells the administrators, once each, which booked bands wait for their calendar.
async def announce_closed_bands(db: AsyncSession, now: datetime) -> PushBatch:
    batches: list[PushBatch] = []
    closed = _closed_bands(now)

    if not closed:
        return joined([])

    first = min(day for day, _ in closed)
    last = max(day for day, _ in closed)
    booked = {
        (day, band_of(start))
        for day, start in await PresenceRepository(db).list_starts(
            date_from=first,
            date_to=last,
        )
    }
    published = {
        (row.date, TimeBandEnum(row.band))
        for row in await db.scalars(
            select(CalendarPublication).where(
                CalendarPublication.date >= first,
                CalendarPublication.date <= last,
            )
        )
    }
    administrators = await reachable_administrators(db)

    for day, band in closed:
        if (day, band) not in booked or (day, band) in published:
            continue

        told = set(
            await db.scalars(
                select(Notification.account_tax_code).where(
                    Notification.kind == NotificationKindEnum.BOOKINGS_CLOSED,
                    Notification.calendar_date == day,
                    Notification.calendar_band == band,
                )
            )
        )
        recipients = [code for code in administrators if code not in told]

        if recipients:
            batches.append(
                await notify(
                    db,
                    recipients,
                    kind=NotificationKindEnum.BOOKINGS_CLOSED,
                    title=_TITLE.format(band=time_band_phrase(band)),
                    body=_BODY,
                    calendar=(day, band),
                )
            )

    return joined(batches)
