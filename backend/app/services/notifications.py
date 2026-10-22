import hashlib
import json
from collections.abc import Sequence
from datetime import UTC, date, datetime
from typing import Any, Final
from urllib.parse import urlsplit

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import TimeBandEnum
from app.models.account import Account, AccountStatusEnum
from app.models.notification import Notification, NotificationKindEnum
from app.models.push_device import PushDevice, PushPlatformEnum
from app.repositories.identity_repository import IdentityRepository
from app.repositories.refresh_token_repository import live_session
from app.services.fcm import AppDismissal, AppPush
from app.services.notification_kinds import wanting
from app.services.push import PushBatch, WebPush
from app.services.role_service import RoleService

# Safari drops a subscription after three pushes that show nothing.
_SILENT_REFUSED_HOST: Final[str] = "push.apple.com"


# Short and stable, to tell later whether something came back as it was.
def fingerprint(value: object) -> str:
    return hashlib.sha256(repr(value).encode()).hexdigest()[:16]


# One that could sign in right now.
def is_reachable(account: Account) -> bool:
    return (
        account.status == AccountStatusEnum.ACTIVE
        and RoleService.access_lapse(account.person) is None
    )


# Every account that could sign in right now, with its role graph.
async def reachable_identities(db: AsyncSession) -> list[Account]:
    accounts = await IdentityRepository(db).get_account_identities()

    return [account for account in accounts if is_reachable(account)]


# Everyone who could sign in right now.
async def reachable_accounts(db: AsyncSession) -> list[str]:
    return [account.tax_code for account in await reachable_identities(db)]


# Those of them who hold the administrator's role.
async def reachable_administrators(db: AsyncSession) -> list[str]:
    return [
        account.tax_code
        for account in await reachable_identities(db)
        if "ADMIN" in RoleService.get_available_roles(account.person)
    ]


# iOS waits for APNs: its devices get nothing yet. A device signed out or blocked
# gets nothing either, though its address is still on file.
async def _devices_of(db: AsyncSession, tax_codes: Sequence[str]) -> list[PushDevice]:
    return list(
        await db.scalars(
            select(PushDevice)
            .where(
                PushDevice.platform.in_(
                    [PushPlatformEnum.WEB, PushPlatformEnum.ANDROID]
                ),
                PushDevice.account_tax_code.in_(list(tax_codes)),
                live_session(
                    PushDevice.account_tax_code,
                    PushDevice.session_id,
                    datetime.now(UTC),
                ),
            )
            .order_by(PushDevice.id)
        )
    )


# One per account that wants the kind; the caller commits, then delivers the pushes.
async def notify(
    db: AsyncSession,
    tax_codes: Sequence[str],
    *,
    kind: NotificationKindEnum,
    title: str,
    body: str,
    web_body: str | None = None,
    calendar: tuple[date, TimeBandEnum] | date | None = None,
    expires_at: datetime | None = None,
    notice_id: int | None = None,
    report_id: int | None = None,
    pupil_tax_code: str | None = None,
    author_tax_code: str | None = None,
    teacher_tax_code: str | None = None,
    teacher_note_id: int | None = None,
    administrator_note_id: int | None = None,
    item_ids: Sequence[int] | None = None,
    known: dict[str, Any] | None = None,
) -> PushBatch:
    calendar_date, calendar_band = (
        (calendar, None) if isinstance(calendar, date) else calendar or (None, None)
    )
    recipients = await wanting(db, list(dict.fromkeys(tax_codes)), kind)
    notifications = [
        Notification(
            account_tax_code=tax_code,
            kind=kind,
            title=title,
            body=body,
            web_body=web_body,
            calendar_date=calendar_date,
            calendar_band=calendar_band,
            expires_at=expires_at,
            notice_id=notice_id,
            report_id=report_id,
            pupil_tax_code=pupil_tax_code,
            author_tax_code=author_tax_code,
            teacher_tax_code=teacher_tax_code,
            teacher_note_id=teacher_note_id,
            administrator_note_id=administrator_note_id,
            item_ids=None if item_ids is None else list(item_ids),
            known=known,
        )
        for tax_code in recipients
    ]
    db.add_all(notifications)
    await db.flush()

    by_account = {
        notification.account_tax_code: notification for notification in notifications
    }
    devices = await _devices_of(db, list(by_account))

    return PushBatch(
        web=[
            _web_push(
                device,
                _payload(
                    by_account[device.account_tax_code],
                    skippable=_accepts_silent_pushes(device),
                ),
            )
            for device in devices
            if device.platform == PushPlatformEnum.WEB
        ],
        android=[
            _app_push(device.address, by_account[device.account_tax_code])
            for device in devices
            if device.platform == PushPlatformEnum.ANDROID
        ],
    )


def _accepts_silent_pushes(device: PushDevice) -> bool:
    host = (urlsplit(device.address).hostname or "").lower()

    return not (
        host == _SILENT_REFUSED_HOST or host.endswith(f".{_SILENT_REFUSED_HOST}")
    )


# Takes them off the system's tray on every device of their owners.
async def dismissals(
    db: AsyncSession,
    notifications: Sequence[Notification],
) -> PushBatch:
    if not notifications:
        return PushBatch(web=[], android=[])

    devices = await _devices_of(
        db,
        list({notification.account_tax_code for notification in notifications}),
    )

    return PushBatch(
        web=[
            _web_push(device, _dismissal_payload(notification))
            for notification in notifications
            for device in devices
            if device.account_tax_code == notification.account_tax_code
            and device.platform == PushPlatformEnum.WEB
            and _accepts_silent_pushes(device)
        ],
        android=[
            AppDismissal(token=device.address, id=notification.id)
            for notification in notifications
            for device in devices
            if device.account_tax_code == notification.account_tax_code
            and device.platform == PushPlatformEnum.ANDROID
        ],
    )


# Off the card and, if unread, every tray; only these owners' when given.
async def withdraw(
    db: AsyncSession,
    *,
    kinds: Sequence[NotificationKindEnum],
    calendar: tuple[date, TimeBandEnum],
    owners: Sequence[str] | None = None,
) -> PushBatch:
    day, band = calendar
    statement = (
        update(Notification)
        .where(
            Notification.kind.in_(list(kinds)),
            Notification.calendar_date == day,
            Notification.calendar_band == band,
            Notification.withdrawn_at.is_(None),
        )
        .values(withdrawn_at=func.now())
        .returning(Notification)
    )

    if owners is not None:
        statement = statement.where(Notification.account_tax_code.in_(list(owners)))

    notifications = list(await db.scalars(statement))
    unread = [row for row in notifications if row.read_at is None]

    return await dismissals(db, unread)


# Those whose moment has come leave the card and, if unread, every tray.
async def expire(db: AsyncSession, now: datetime) -> PushBatch:
    notifications = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.expires_at <= now,
                Notification.withdrawn_at.is_(None),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

    return await dismissals(
        db,
        [row for row in notifications if row.read_at is None],
    )


def _web_push(device: PushDevice, payload: str) -> WebPush:
    return WebPush(
        address=device.address,
        p256dh=device.p256dh or "",
        auth=device.auth or "",
        payload=payload,
    )


def _app_push(token: str, notification: Notification) -> AppPush:
    return AppPush(
        token=token,
        id=notification.id,
        kind=notification.kind.value,
        title=notification.title,
        body=notification.body,
    )


# Skippable: no banner while the app is in front; browsers get the desktop's wording.
def _payload(notification: Notification, *, skippable: bool) -> str:
    return json.dumps(
        {
            "id": notification.id,
            "kind": notification.kind.value,
            "title": notification.title,
            "body": notification.web_body or notification.body,
            "skippable": skippable,
        },
        ensure_ascii=False,
    )


def _dismissal_payload(notification: Notification) -> str:
    return json.dumps({"type": "dismiss", "id": notification.id})
