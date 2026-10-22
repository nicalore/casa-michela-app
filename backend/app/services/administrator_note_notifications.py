from typing import Final

from sqlalchemy import ColumnElement, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator_note import AdministratorNote
from app.models.notification import Notification, NotificationKindEnum
from app.models.person import Person
from app.repositories.identity_repository import IdentityRepository
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, is_reachable, notify
from app.services.push import PushBatch, joined

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.ADMINISTRATOR_NOTE_ADDED

_TITLE: Final[str] = "{author} ha aggiunto una nuova osservazione per te"
_BODY: Final[str] = "Tocca per leggerla"
_WEB_BODY: Final[str] = "Clicca per leggerla"


# The teacher, unless they wrote it; the caller commits, then delivers the pushes.
async def announce_administrator_note(
    db: AsyncSession,
    note: AdministratorNote,
) -> PushBatch:
    await db.flush()

    if note.teacher_tax_code == note.author_tax_code:
        return joined([])

    account = await IdentityRepository(db).get_account_identity(note.teacher_tax_code)

    if account is None or not is_reachable(account) or not holds_kind(account, _KIND):
        return joined([])

    author = await db.get(Person, note.author_tax_code)

    if author is None:
        return joined([])

    return await notify(
        db,
        [account.tax_code],
        kind=_KIND,
        title=_TITLE.format(author=f"{author.first_name} {author.last_name}"),
        body=_BODY,
        web_body=_WEB_BODY,
        author_tax_code=author.tax_code,
        administrator_note_id=note.id,
    )


# The teacher's notes on their screen: their news has done its work.
async def administrator_notes_seen(db: AsyncSession, tax_code: str) -> PushBatch:
    rows = await _withdraw(db, Notification.account_tax_code == tax_code)

    return await dismissals(db, [row for row in rows if row.read_at is None])


# Deleted: nobody is told of it any more.
async def administrator_note_deleted(db: AsyncSession, note_id: int) -> PushBatch:
    rows = await _withdraw(db, Notification.administrator_note_id == note_id)

    # Read ones too: the push is what makes every device drop it from its card.
    return await dismissals(db, rows)


async def _withdraw(
    db: AsyncSession,
    *where: ColumnElement[bool],
) -> list[Notification]:
    return list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.withdrawn_at.is_(None),
                *where,
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )
