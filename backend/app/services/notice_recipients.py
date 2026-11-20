from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from typing import Final

from sqlalchemy import ColumnElement, delete, inspect, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.i18n import ENGLISH, ITALIAN
from app.models.member import Member
from app.models.notice import Notice, NoticeExclusion, NoticeRoleEnum
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.staff import Staff
from app.services.collaboration import is_collaborating
from app.services.role_service import RoleService

# Reached as such only by active collaborators.
COLLABORATOR_ROLES: Final[frozenset[NoticeRoleEnum]] = frozenset(
    {NoticeRoleEnum.TEACHER, NoticeRoleEnum.STUDENT}
)


# The roles a notice can reach this person by, under the rules of access.
def notice_roles_of(person: Person) -> frozenset[NoticeRoleEnum]:
    roles = {NoticeRoleEnum(role) for role in RoleService.get_available_roles(person)}
    member = person.member_profile

    if member is not None and RoleService.in_good_standing(member):
        roles.add(NoticeRoleEnum.MEMBER)

    return frozenset(roles)


# The roles held that a notice was sent to; one that left this person out
# reaches them neither as teacher nor as student.
def reached_roles(
    roles: Iterable[str],
    recipients: Iterable[NoticeRoleEnum],
    *,
    excluded: bool = False,
) -> list[str]:
    sent = {role.value for role in recipients}

    if excluded:
        sent -= {role.value for role in COLLABORATOR_ROLES}

    return sorted(role for role in roles if role in sent)


# Teachers and students it reaches as such only while active collaborators.
def _reaching_roles_of(person: Person) -> frozenset[NoticeRoleEnum]:
    roles = notice_roles_of(person)

    if is_collaborating(person.member_profile):
        return roles

    return roles - COLLABORATOR_ROLES


async def _candidates(db: AsyncSession) -> list[Person]:
    member = joinedload(Person.member_profile)
    staff = member.joinedload(Member.staff_profile)
    child_member = (
        joinedload(Person.parent_profile)
        .selectinload(Parent.children_relationships)
        .joinedload(ParentalResponsibility.child)
        .joinedload(Person.member_profile)
    )

    people = await db.scalars(
        select(Person)
        .options(
            joinedload(Person.account),
            child_member.joinedload(Member.student_profile),
            child_member.selectinload(Member.memberships),
            member.joinedload(Member.student_profile),
            member.joinedload(Member.course_participant_profile),
            member.selectinload(Member.memberships),
            staff.joinedload(Staff.administrator_profile),
            staff.joinedload(Staff.teacher_profile),
            staff.joinedload(Staff.psychologist_profile),
        )
        .where(or_(Person.member_profile.has(), Person.parent_profile.has()))
        .order_by(Person.tax_code)
    )

    return list(people.unique())


def _holding(
    people: Iterable[Person],
    wanted: frozenset[NoticeRoleEnum],
    roles_of: Callable[[Person], frozenset[NoticeRoleEnum]],
    excluding: str | None,
) -> list[Person]:
    return [
        person
        for person in people
        if person.tax_code != excluding and not wanted.isdisjoint(roles_of(person))
    ]


# Everyone holding one of the roles today, each person once.
async def recipients_of(
    db: AsyncSession,
    roles: Iterable[NoticeRoleEnum],
    *,
    excluding: str | None = None,
) -> list[Person]:
    wanted = frozenset(roles)

    if not wanted:
        return []

    return _holding(await _candidates(db), wanted, notice_roles_of, excluding)


@dataclass(frozen=True)
class NoticeReach:
    # Each person once, mailed and told in the app.
    reached: list[Person]
    # Teachers and students it is sent to as such while not collaborating.
    excluded: list[str]


async def notice_reach(
    db: AsyncSession,
    roles: Iterable[NoticeRoleEnum],
    *,
    excluding: str | None = None,
) -> NoticeReach:
    wanted = frozenset(roles)

    if not wanted:
        return NoticeReach(reached=[], excluded=[])

    people = await _candidates(db)
    left_out = wanted & COLLABORATOR_ROLES

    return NoticeReach(
        reached=_holding(people, wanted, _reaching_roles_of, excluding),
        excluded=[
            person.tax_code
            for person in people
            if not is_collaborating(person.member_profile)
            and not left_out.isdisjoint(notice_roles_of(person))
        ],
    )


# The last sending decides: an edit sets them again.
async def exclude(db: AsyncSession, notice_id: int, tax_codes: list[str]) -> None:
    await db.execute(
        delete(NoticeExclusion).where(NoticeExclusion.notice_id == notice_id)
    )
    db.add_all(
        NoticeExclusion(notice_id=notice_id, tax_code=tax_code)
        for tax_code in tax_codes
    )
    await db.flush()


async def excluded_from(db: AsyncSession, notice_id: int) -> frozenset[str]:
    return frozenset(
        await db.scalars(
            select(NoticeExclusion.tax_code).where(
                NoticeExclusion.notice_id == notice_id
            )
        )
    )


# The notices among these that left this person out as teacher or student.
async def notices_excluding(
    db: AsyncSession,
    tax_code: str,
    notice_ids: Iterable[int],
) -> frozenset[int]:
    ids = list(notice_ids)

    if not ids:
        return frozenset()

    return frozenset(
        await db.scalars(
            select(NoticeExclusion.notice_id).where(
                NoticeExclusion.tax_code == tax_code,
                NoticeExclusion.notice_id.in_(ids),
            )
        )
    )


def not_excluding(tax_code: str) -> ColumnElement[bool]:
    return Notice.id.not_in(
        select(NoticeExclusion.notice_id).where(NoticeExclusion.tax_code == tax_code)
    )


@dataclass(frozen=True)
class MailAddress:
    email: str
    # None for Italian.
    language: str | None = None


def _chosen_language(person: Person) -> str | None:
    if "account" in inspect(person).unloaded or person.account is None:
        return None

    return person.account.language


# A shared mailbox reads English only if someone behind it chose English and
# nobody chose Italian: an explicit Italian, or a clash, keeps Italian.
def _mailbox_language(chosen: Iterable[str | None]) -> str | None:
    languages = {language for language in chosen if language is not None}

    return ENGLISH if ENGLISH in languages and ITALIAN not in languages else None


# One address per mailbox: relatives often share one, in any capitalisation.
def unique_addresses(people: Sequence[Person]) -> list[MailAddress]:
    first: dict[str, str] = {}
    chosen: dict[str, list[str | None]] = {}

    for person in people:
        key = person.email.casefold()
        first.setdefault(key, person.email)
        chosen.setdefault(key, []).append(_chosen_language(person))

    return [
        MailAddress(email, _mailbox_language(chosen[key]))
        for key, email in first.items()
    ]
