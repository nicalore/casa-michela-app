from datetime import date, datetime, time, timedelta
from typing import Final

from sqlalchemy import exists, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.account import Account
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.member import Member
from app.models.membership import Membership
from app.models.notification import Notification, NotificationKindEnum
from app.models.person import Person
from app.models.teacher import Teacher
from app.repositories.identity_repository import IdentityRepository
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, is_reachable, notify
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.RATING_REMINDER

_TITLE: Final[str] = "Avvisa di aggiornare la valutazione di {name}"
_BODY: Final[str] = "Tocca per farlo"
_WEB_BODY: Final[str] = "Clicca per farlo"

_AFTER: Final[timedelta] = timedelta(days=14)

# An enrollment written in late is still told for a week; older ones are no news.
_GRACE: Final[timedelta] = timedelta(days=7)

# Mornings only: one written in late waits for the next.
_FROM: Final[time] = time(9)
_UNTIL: Final[time] = time(10)


# Still enrolled teachers whose first enrollment began two weeks ago, not yet told.
async def _due_teachers(db: AsyncSession, today: date) -> list[Person]:
    first = (
        select(
            Membership.member_tax_code.label("tax_code"),
            func.min(Membership.start_date).label("start_date"),
        )
        .group_by(Membership.member_tax_code)
        .subquery()
    )
    people = await db.scalars(
        select(Person)
        .join(Teacher, Teacher.tax_code == Person.tax_code)
        .join(first, first.c.tax_code == Person.tax_code)
        .where(
            first.c.start_date <= today - _AFTER,
            first.c.start_date > today - _AFTER - _GRACE,
            ~exists().where(
                Notification.kind == _KIND,
                Notification.teacher_tax_code == Person.tax_code,
            ),
        )
        .options(
            selectinload(Person.member_profile).selectinload(Member.memberships),
        )
        .order_by(first.c.start_date, Person.last_name, Person.first_name)
    )

    return [
        person for person in people if RoleService.is_enrolled(person.member_profile)
    ]


# The president, if they could sign in right now and keep the kind on.
async def _president(db: AsyncSession) -> Account | None:
    tax_code = await db.scalar(
        select(Administrator.tax_code).where(
            Administrator.role == AdministratorRoleEnum.PRESIDENT,
        )
    )
    account = (
        await IdentityRepository(db).get_account_identity(tax_code)
        if tax_code is not None
        else None
    )

    if account is None or not is_reachable(account) or not holds_kind(account, _KIND):
        return None

    return account


# Mornings at 9: the president asked to rate each new teacher, two weeks on.
async def remind_ratings(db: AsyncSession, now: datetime) -> PushBatch:
    if not _FROM <= now.time() < _UNTIL:
        return joined([])

    teachers = await _due_teachers(db, now.date())
    president = await _president(db) if teachers else None

    if president is None:
        return joined([])

    return joined(
        [
            await notify(
                db,
                [president.tax_code],
                kind=_KIND,
                title=_TITLE.format(name=f"{teacher.first_name} {teacher.last_name}"),
                body=_BODY,
                web_body=_WEB_BODY,
                teacher_tax_code=teacher.tax_code,
            )
            for teacher in teachers
            if teacher.tax_code != president.tax_code
        ]
    )


# The rating changed, or the teacher is one no more: nothing is left to ask.
async def rating_updated(db: AsyncSession, teacher_tax_code: str) -> PushBatch:
    rows = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.teacher_tax_code == teacher_tax_code,
                Notification.withdrawn_at.is_(None),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

    return await dismissals(db, [row for row in rows if row.read_at is None])
