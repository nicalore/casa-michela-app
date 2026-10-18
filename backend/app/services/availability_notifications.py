from collections.abc import Mapping
from datetime import date
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.notification import NotificationKindEnum
from app.models.person import Person
from app.repositories.identity_repository import IdentityRepository
from app.services import change_notices
from app.services.change_notices import Item, Scene, Texts, Topic
from app.services.notifications import is_reachable
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_AVAILABILITIES: Final[Topic] = Topic(
    added=NotificationKindEnum.AVAILABILITY_ADDED,
    changed=NotificationKindEnum.AVAILABILITY_CHANGED,
    cancelled=NotificationKindEnum.AVAILABILITY_CANCELLED,
    texts={
        NotificationKindEnum.AVAILABILITY_ADDED: Texts(
            one="{author} ha inserito una nuova disponibilità",
            many="{author} ha inserito nuove disponibilità",
            body_one="Tocca per visualizzarla",
            web_body_one="Clicca per visualizzarla",
            body_many="Tocca per visualizzarle",
            web_body_many="Clicca per visualizzarle",
        ),
        NotificationKindEnum.AVAILABILITY_CHANGED: Texts(
            one="{author} ha modificato una disponibilità",
            many="{author} ha modificato alcune disponibilità",
            body_one="Tocca per visualizzare le disponibilità",
            web_body_one="Clicca per visualizzare le disponibilità",
            body_many="Tocca per visualizzare le disponibilità",
            web_body_many="Clicca per visualizzare le disponibilità",
        ),
        NotificationKindEnum.AVAILABILITY_CANCELLED: Texts(
            one="{author} ha cancellato una disponibilità",
            many="{author} ha cancellato alcune disponibilità",
            body_one="Tocca per visualizzare le disponibilità",
            web_body_one="Clicca per visualizzare le disponibilità",
            body_many="Tocca per visualizzare le disponibilità",
            web_body_many="Clicca per visualizzare le disponibilità",
        ),
    },
)


# Its teacher and itself as the teacher sees it, before and after a write.
async def teacher_availability(
    db: AsyncSession,
    availability_id: int,
) -> tuple[str | None, dict[int, Item]]:
    row = (
        await db.execute(
            select(
                Availability.teacher_tax_code,
                Availability.date,
                Availability.mode,
                Availability.start_time,
                Availability.end_time,
            ).where(Availability.id == availability_id)
        )
    ).first()

    if row is None:
        return None, {}

    return row.teacher_tax_code, {
        availability_id: Item(
            row.date,
            (row.date, row.mode, row.start_time, row.end_time),
        ),
    }


# Written for a teacher by someone else, an administrator: the teacher hears of it.
async def tell_availability_changes(
    db: AsyncSession,
    *,
    author_tax_code: str,
    teacher_tax_code: str | None,
    before: Mapping[int, Item],
    after: Mapping[int, Item],
) -> PushBatch:
    if teacher_tax_code is None:
        return joined([])

    author = await db.get(Person, author_tax_code)
    teacher = await db.get(Person, teacher_tax_code)
    account = await IdentityRepository(db).get_account_identity(teacher_tax_code)

    if author is None or teacher is None:
        return joined([])

    readers = (
        [account]
        if teacher_tax_code != author_tax_code
        and account is not None
        and is_reachable(account)
        and "TEACHER" in RoleService.get_available_roles(account.person)
        else []
    )

    return await change_notices.tell_changes(
        db,
        _AVAILABILITIES,
        Scene(author=author, owner=teacher, readers=readers),
        before,
        after,
    )


# Those days of one's own availabilities on screen: what told of them is seen.
async def availabilities_seen(
    db: AsyncSession,
    tax_code: str,
    first: date,
    last: date,
) -> PushBatch:
    return await change_notices.seen(db, _AVAILABILITIES, tax_code, first, last)
