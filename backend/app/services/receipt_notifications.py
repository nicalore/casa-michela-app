from datetime import date
from typing import Final

from sqlalchemy import ColumnElement, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import month_name
from app.models.notification import Notification, NotificationKindEnum
from app.repositories.identity_repository import IdentityRepository
from app.services.bilingual import Bilingual
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, is_reachable, notify
from app.services.push import PushBatch, joined

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.PAYMENT_RECEIPT_AVAILABLE

_TITLE: Final[Bilingual] = Bilingual(
    "La ricevuta del pagamento del mese di {month} è disponibile",
    "The payment receipt for {month} is available",
)
_BODY: Final[Bilingual] = Bilingual(
    "Tocca per visualizzarla",
    "Tap to view it",
)
_WEB_BODY: Final[Bilingual] = Bilingual(
    "Clicca per visualizzarla",
    "Click to view it",
)


async def _withdraw(
    db: AsyncSession,
    *where: ColumnElement[bool],
) -> PushBatch:
    rows = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.withdrawn_at.is_(None),
                *where,
            )
            .values(withdrawn_at=func.now())
            .returning(Notification),
        )
    )

    return await dismissals(db, [row for row in rows if row.read_at is None])


def _of_month(tax_code: str, month: date) -> list[ColumnElement[bool]]:
    return [
        Notification.account_tax_code == tax_code,
        Notification.calendar_date == month,
    ]


# A receipt uploaded, or a new one in its place: the teacher hears of it once more.
# The caller commits, then delivers.
async def announce_receipt(
    db: AsyncSession,
    tax_code: str,
    month: date,
    author_tax_code: str | None,
) -> PushBatch:
    gone = await _withdraw(db, *_of_month(tax_code, month))

    if tax_code == author_tax_code:
        return gone

    account = await IdentityRepository(db).get_account_identity(tax_code)

    if account is None or not is_reachable(account) or not holds_kind(account, _KIND):
        return gone

    told = await notify(
        db,
        [tax_code],
        kind=_KIND,
        title=Bilingual(
            _TITLE.to("it").format(month=month_name(month.month, "it")),
            _TITLE.to("en").format(month=month_name(month.month, "en")),
        ),
        body=_BODY,
        web_body=_WEB_BODY,
        calendar=month,
        author_tax_code=author_tax_code,
    )

    return joined([gone, told])


# The receipt deleted, or the month's pay on the teacher's screen: the news goes.
async def receipt_gone(db: AsyncSession, tax_code: str, month: date) -> PushBatch:
    return await _withdraw(db, *_of_month(tax_code, month))
