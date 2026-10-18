import hashlib
from collections.abc import Sequence
from typing import Final

from sqlalchemy import exists, func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.known_device import KnownDevice
from app.models.notification import Notification, NotificationKindEnum
from app.models.person import GenderEnum, Person
from app.services.notifications import dismissals, notify
from app.services.push import PushBatch, joined

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.NEW_DEVICE

_TITLE: Final[str] = "Nuovo accesso da {device}"
_UNNAMED: Final[str] = "un dispositivo sconosciuto"
_BODIES: Final[dict[GenderEnum, str]] = {
    GenderEnum.M: "Se non sei stato tu, blocca il dispositivo",
    GenderEnum.F: "Se non sei stata tu, blocca il dispositivo",
}

# Codes longer than this are no codes the apps send.
_KEY_LENGTH: Final[int] = 128


# Seen signing in or refreshing: a code never seen for the account is learned; a
# sign-in from it, where others were known, is told to the account.
async def device_seen(
    db: AsyncSession,
    tax_code: str,
    key: str | None,
    *,
    session_id: str | None = None,
    device_name: str | None = None,
) -> PushBatch:
    key = (key or "").strip()

    if not key or len(key) > _KEY_LENGTH:
        return joined([])

    known_before = await db.scalar(
        select(exists().where(KnownDevice.account_tax_code == tax_code))
    )
    learned = await db.scalar(
        insert(KnownDevice)
        .values(
            account_tax_code=tax_code,
            key_hash=hashlib.sha256(key.encode()).hexdigest(),
        )
        .on_conflict_do_nothing(index_elements=["account_tax_code", "key_hash"])
        .returning(KnownDevice.id)
    )

    # A refresh, a device seen before, or the account's first one: nothing to tell.
    if session_id is None or learned is None or not known_before:
        return joined([])

    person = await db.get(Person, tax_code)
    gender = person.gender if person is not None else GenderEnum.M
    body = _BODIES.get(gender, _BODIES[GenderEnum.M])

    return await notify(
        db,
        [tax_code],
        kind=_KIND,
        title=_TITLE.format(device=device_name or _UNNAMED),
        body=body,
        known={"session": session_id},
    )


# Sessions ended from the devices list: the news of their sign-ins goes too, all
# but the one in use when kept.
async def sessions_ended(
    db: AsyncSession,
    tax_code: str,
    *,
    sessions: Sequence[str] | None = None,
    keep: str | None = None,
) -> PushBatch:
    session = Notification.known["session"].astext
    statement = (
        update(Notification)
        .where(
            Notification.kind == _KIND,
            Notification.account_tax_code == tax_code,
            Notification.withdrawn_at.is_(None),
        )
        .values(withdrawn_at=func.now())
        .returning(Notification)
    )

    if sessions is not None:
        statement = statement.where(session.in_(list(sessions)))

    if keep is not None:
        statement = statement.where(session.is_distinct_from(keep))

    rows = list(await db.scalars(statement))

    return await dismissals(db, [row for row in rows if row.read_at is None])


# The sign-in in use is no news to the device it happened on.
def about_session(row: Notification, session_id: str | None) -> bool:
    return (
        row.kind == _KIND
        and session_id is not None
        and (row.known or {}).get("session") == session_id
    )
