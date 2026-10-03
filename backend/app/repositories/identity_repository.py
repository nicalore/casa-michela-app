from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload

from app.models.account import Account
from app.models.member import Member
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.staff import Staff
from app.repositories.base import SessionRepository


class IdentityRepository(SessionRepository):
    # One statement for the one-to-one chain; only the collections use an IN.
    async def get_account_identity(self, tax_code: str) -> Account | None:
        person = joinedload(Account.person)
        member = person.joinedload(Person.member_profile)
        staff = member.joinedload(Member.staff_profile)

        # Whether each child is an enrolled pupil decides the parent role.
        child_member = (
            person.joinedload(Person.parent_profile)
            .selectinload(Parent.children_relationships)
            .joinedload(ParentalResponsibility.child)
            .joinedload(Person.member_profile)
        )

        return await self.session.scalar(
            select(Account)
            .options(
                child_member.joinedload(Member.student_profile),
                child_member.selectinload(Member.memberships),
                person.selectinload(Person.parental_relationships),
                member.joinedload(Member.student_profile),
                member.joinedload(Member.course_participant_profile),
                member.selectinload(Member.memberships),
                staff.joinedload(Staff.administrator_profile),
                staff.joinedload(Staff.teacher_profile),
                staff.joinedload(Staff.psychologist_profile),
            )
            .where(Account.tax_code == tax_code)
        )

    # The same role graph from the person's side, for one who may have no account yet.
    async def get_person_identity(self, tax_code: str) -> Person | None:
        member = joinedload(Person.member_profile)
        staff = member.joinedload(Member.staff_profile)
        child_member = (
            joinedload(Person.parent_profile)
            .selectinload(Parent.children_relationships)
            .joinedload(ParentalResponsibility.child)
            .joinedload(Person.member_profile)
        )

        return await self.session.scalar(
            select(Person)
            .options(
                joinedload(Person.account),
                child_member.joinedload(Member.student_profile),
                child_member.selectinload(Member.memberships),
                # Their accounts decide whether the pupil's brings theirs along.
                selectinload(Person.parental_relationships)
                .joinedload(ParentalResponsibility.parent)
                .joinedload(Parent.person)
                .joinedload(Person.account),
                member.joinedload(Member.student_profile),
                member.joinedload(Member.course_participant_profile),
                member.selectinload(Member.memberships),
                staff.joinedload(Staff.administrator_profile),
                staff.joinedload(Staff.teacher_profile),
                staff.joinedload(Staff.psychologist_profile),
            )
            .where(Person.tax_code == tax_code)
        )
