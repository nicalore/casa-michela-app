from collections.abc import Collection, Iterable
from typing import Final

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notice import Notice, NoticeRoleEnum
from app.models.notification import Notification, NotificationKindEnum
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, notify, reachable_identities
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.NOTICE_RECEIVED

_TITLE: Final[str] = "C'è una nuova comunicazione per te"
_BODY: Final[str] = "Tocca per leggerla"
_WEB_BODY: Final[str] = "Clicca per leggerla"

def reached_roles(
    roles: Iterable[str],
    recipients: Iterable[NoticeRoleEnum],
) -> list[str]:
    sent = {role.value for role in recipients}

    return sorted(role for role in roles if role in sent)


async def _forget(
    db: AsyncSession,
    notice_id: int,
    owners: Collection[str] | None = None,
) -> PushBatch:
    if owners is not None and not owners:
        return joined([])

    statement = (
        delete(Notification)
        .where(Notification.kind == _KIND, Notification.notice_id == notice_id)
        .returning(Notification)
    )

    if owners is not None:
        statement = statement.where(Notification.account_tax_code.in_(list(owners)))

    rows = list(await db.scalars(statement))

    return await dismissals(
        db,
        [row for row in rows if row.read_at is None and row.withdrawn_at is None],
    )


# Everyone it reaches in the app but its author; an edit tells only whom it newly
# reaches, and those it no longer reaches lose theirs.
async def announce_notice(db: AsyncSession, notice: Notice) -> PushBatch:
    readers = {
        account.tax_code
        for account in await reachable_identities(db)
        if account.tax_code != notice.author_tax_code
        and holds_kind(account, _KIND)
        and reached_roles(
            RoleService.get_available_roles(account.person),
            notice.recipients,
        )
    }
    told = set(
        await db.scalars(
            select(Notification.account_tax_code).where(
                Notification.kind == _KIND,
                Notification.notice_id == notice.id,
            )
        )
    )

    return joined(
        [
            await _forget(db, notice.id, told - readers),
            await notify(
                db,
                sorted(readers - told),
                kind=_KIND,
                title=_TITLE,
                body=_BODY,
                web_body=_WEB_BODY,
                notice_id=notice.id,
            ),
        ]
    )


# Opened by its reader: what announced it has done its work.
async def notice_read(db: AsyncSession, notice_id: int, tax_code: str) -> PushBatch:
    rows = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.notice_id == notice_id,
                Notification.account_tax_code == tax_code,
                Notification.withdrawn_at.is_(None),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

    return await dismissals(db, [row for row in rows if row.read_at is None])


# Before the notice is deleted, while the trays can still be told.
async def notice_deleted(db: AsyncSession, notice_id: int) -> PushBatch:
    return await _forget(db, notice_id)
