from collections.abc import Iterable, Sequence

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.member import Member
from app.models.notice import NoticeRoleEnum
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.staff import Staff
from app.services.role_service import RoleService


# The roles a notice can reach this person by, under the rules of access.
def notice_roles_of(person: Person) -> frozenset[NoticeRoleEnum]:
    roles = {NoticeRoleEnum(role) for role in RoleService.get_available_roles(person)}
    member = person.member_profile

    if member is not None and RoleService.in_good_standing(member):
        roles.add(NoticeRoleEnum.MEMBER)

    return frozenset(roles)


# Everyone holding one of the roles today, each person once.
async def recipients_of(
    db: AsyncSession,
    roles: Iterable[NoticeRoleEnum],
) -> list[Person]:
    wanted = frozenset(roles)

    if not wanted:
        return []

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

    return [
        person
        for person in people.unique()
        if not wanted.isdisjoint(notice_roles_of(person))
    ]


# One address per mailbox: relatives often share one, in any capitalisation.
def unique_addresses(people: Sequence[Person]) -> list[str]:
    seen: set[str] = set()
    addresses: list[str] = []

    for person in people:
        key = person.email.casefold()

        if key in seen:
            continue

        seen.add(key)
        addresses.append(person.email)

    return addresses
