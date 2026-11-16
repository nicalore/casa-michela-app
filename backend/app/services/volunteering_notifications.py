from collections.abc import Callable
from datetime import date
from typing import Final

from sqlalchemy import ColumnElement, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import MONTH_NAMES
from app.models.notification import Notification, NotificationKindEnum
from app.models.volunteering import VolunteeringRule, VolunteeringRuleChange
from app.repositories.identity_repository import IdentityRepository
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, is_reachable, notify
from app.services.push import PushBatch, joined

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.VOLUNTEERING_CHANGED

_FOR_MONTH: Final[str] = (
    "Ti è stata assegnata un'ora di volontariato {rule} per il mese di {month}"
)
_NONE_FOR_MONTH: Final[str] = (
    "Per il mese di {month} non ti è assegnata nessuna ora di volontariato"
)
_FROM_MONTH: Final[str] = (
    "Dal mese di {month} ti è stata assegnata un'ora di volontariato {rule}"
)
_NONE_FROM_MONTH: Final[str] = (
    "Dal mese di {month} non ti è assegnata nessuna ora di volontariato"
)
_RULE_WORDS: Final[dict[VolunteeringRule, str]] = {
    VolunteeringRule.DAILY: "al giorno",
    VolunteeringRule.WEEKLY: "a settimana",
}
_BODY: Final[str] = "Tocca per visualizzare la paga aggiornata"
_WEB_BODY: Final[str] = "Clicca per visualizzare la paga aggiornata"

# What a notice keeps: the month's rule before its news, and whether it tells a
# rule from that month on rather than for that month alone.
_BEFORE: Final[str] = "rule"
_FROM: Final[str] = "from"


def _title(month: date, rule: VolunteeringRule, from_month: bool) -> str:
    name = MONTH_NAMES[month.month - 1]

    if rule == VolunteeringRule.NONE:
        return (_NONE_FROM_MONTH if from_month else _NONE_FOR_MONTH).format(
            month=name,
        )

    return (_FROM_MONTH if from_month else _FOR_MONTH).format(
        rule=_RULE_WORDS[rule],
        month=name,
    )


def _tells_from(row: Notification) -> bool:
    return bool((row.known or {}).get(_FROM))


# The teacher hears how their unpaid hour now counts, unless they set it themself:
# for one month from the monthly summary, or from a month on from their Compensi.
# The news it makes old goes. If the teacher had not read it yet and the month is
# back to what they knew, nothing new is told. The caller commits, then delivers.
async def announce_volunteering_rule(
    db: AsyncSession,
    tax_code: str,
    month: date,
    rule: VolunteeringRule,
    before: VolunteeringRule,
    author_tax_code: str | None,
    *,
    from_month: bool = False,
) -> PushBatch:
    covers = await _covered(db, tax_code, month, from_month)
    live = await db.scalars(
        select(Notification).where(
            Notification.kind == _KIND,
            Notification.account_tax_code == tax_code,
            Notification.withdrawn_at.is_(None),
        ),
    )
    replaced = [row for row in live if covers(row)]
    earlier = await _withdraw(db, Notification.id.in_([row.id for row in replaced]))
    unread = sorted(
        (row for row in earlier if row.read_at is None),
        key=lambda row: row.id,
    )
    gone = await dismissals(db, unread)

    # What the teacher knew of the month, before news they never read.
    seen = [
        row
        for row in unread
        if row.calendar_date == month and _tells_from(row) == from_month
    ]
    knew = (seen[0].known or {}).get(_BEFORE) if seen else before.value

    if knew == rule.value or tax_code == author_tax_code:
        return gone

    account = await IdentityRepository(db).get_account_identity(tax_code)

    if account is None or not is_reachable(account) or not holds_kind(account, _KIND):
        return gone

    told = await notify(
        db,
        [tax_code],
        kind=_KIND,
        title=_title(month, rule, from_month),
        body=_BODY,
        web_body=_WEB_BODY,
        calendar=month,
        author_tax_code=author_tax_code,
        known={_BEFORE: knew, _FROM: from_month},
    )

    return joined([gone, told])


# The month's own news; a rule from a month on makes old every month's news up to
# the teacher's next change, which stays.
async def _covered(
    db: AsyncSession,
    tax_code: str,
    month: date,
    from_month: bool,
) -> Callable[[Notification], bool]:
    if not from_month:
        return lambda row: row.calendar_date == month and not _tells_from(row)

    until = await db.scalar(
        select(func.min(VolunteeringRuleChange.starts_on)).where(
            VolunteeringRuleChange.staff_tax_code == tax_code,
            VolunteeringRuleChange.starts_on > month,
        ),
    )

    return lambda row: row.calendar_date is not None and (
        month <= row.calendar_date and (until is None or row.calendar_date < until)
    )


# The teacher's pay on their screen: the news has done its work.
async def compensation_seen(db: AsyncSession, tax_code: str) -> PushBatch:
    rows = await _withdraw(db, Notification.account_tax_code == tax_code)

    return await dismissals(db, [row for row in rows if row.read_at is None])


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
            .returning(Notification),
        )
    )
