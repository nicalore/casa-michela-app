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
from app.services.notifications import Bilingual, is_reachable
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_TAP_FOR_AVAILABILITY: Final[Bilingual] = Bilingual(
    "Tocca per visualizzare le disponibilità",
    "Tap to view the availability",
)
_CLICK_FOR_AVAILABILITY: Final[Bilingual] = Bilingual(
    "Clicca per visualizzare le disponibilità",
    "Click to view the availability",
)

_AVAILABILITIES: Final[Topic] = Topic(
    added=NotificationKindEnum.AVAILABILITY_ADDED,
    changed=NotificationKindEnum.AVAILABILITY_CHANGED,
    cancelled=NotificationKindEnum.AVAILABILITY_CANCELLED,
    texts={
        NotificationKindEnum.AVAILABILITY_ADDED: Texts(
            one=Bilingual(
                "{author} ha inserito una nuova disponibilità per te",
                "{author} added new availability for you",
            ),
            many=Bilingual(
                "{author} ha inserito nuove disponibilità per te",
                "{author} added new availability for you",
            ),
            body_one=Bilingual("Tocca per visualizzarla", "Tap to view it"),
            web_body_one=Bilingual("Clicca per visualizzarla", "Click to view it"),
            body_many=Bilingual("Tocca per visualizzarle", "Tap to view it"),
            web_body_many=Bilingual("Clicca per visualizzarle", "Click to view it"),
        ),
        NotificationKindEnum.AVAILABILITY_CHANGED: Texts(
            one=Bilingual(
                "{author} ha modificato una tua disponibilità",
                "{author} changed some of your availability",
            ),
            many=Bilingual(
                "{author} ha modificato alcune tue disponibilità",
                "{author} changed some of your availability",
            ),
            body_one=Bilingual("Tocca per visualizzarla", "Tap to view it"),
            web_body_one=Bilingual("Clicca per visualizzarla", "Click to view it"),
            body_many=Bilingual("Tocca per visualizzarle", "Tap to view it"),
            web_body_many=Bilingual("Clicca per visualizzarle", "Click to view it"),
        ),
        NotificationKindEnum.AVAILABILITY_CANCELLED: Texts(
            one=Bilingual(
                "{author} ha cancellato una tua disponibilità",
                "{author} cancelled some of your availability",
            ),
            many=Bilingual(
                "{author} ha cancellato alcune tue disponibilità",
                "{author} cancelled some of your availability",
            ),
            body_one=_TAP_FOR_AVAILABILITY,
            web_body_one=_CLICK_FOR_AVAILABILITY,
            body_many=_TAP_FOR_AVAILABILITY,
            web_body_many=_CLICK_FOR_AVAILABILITY,
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
