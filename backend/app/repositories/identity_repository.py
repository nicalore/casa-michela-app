from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.models.account import Account
from app.models.member import Member
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.staff import Staff
from app.repositories.base import SessionRepository


class IdentityRepository(SessionRepository):
    # One statement for the one-to-one chain; only the two collections use an IN.
    async def get_account_identity(self, tax_code: str) -> Account | None:
        person = joinedload(Account.person)
        member = person.joinedload(Person.member_profile)
        staff = member.joinedload(Member.staff_profile)

        return await self.session.scalar(
            select(Account)
            .options(
                # Whether each child is a pupil decides the parent role.
                person.joinedload(Person.parent_profile)
                .selectinload(Parent.children_relationships)
                .joinedload(ParentalResponsibility.child)
                .joinedload(Person.member_profile)
                .joinedload(Member.student_profile),
                person.selectinload(Person.parental_relationships),
                member.joinedload(Member.student_profile),
                member.joinedload(Member.course_participant_profile),
                staff.joinedload(Staff.administrator_profile),
                staff.joinedload(Staff.teacher_profile),
                staff.joinedload(Staff.psychologist_profile),
            )
            .where(Account.tax_code == tax_code)
        )
