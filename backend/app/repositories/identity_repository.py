from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.account import Account
from app.models.member import Member
from app.models.parent import Parent
from app.models.person import Person
from app.models.staff import Staff
from app.repositories.base import SessionRepository


class IdentityRepository(SessionRepository):
    async def get_account_identity(self, tax_code: str) -> Account | None:
        person_loader = selectinload(Account.person)
        parent_loader = person_loader.selectinload(Person.parent_profile)
        member_loader = person_loader.selectinload(Person.member_profile)
        staff_loader = member_loader.selectinload(Member.staff_profile)

        return await self.session.scalar(
            select(Account)
            .options(
                parent_loader.selectinload(Parent.children_relationships),
                member_loader.selectinload(Member.student_profile),
                member_loader.selectinload(Member.course_participant_profile),
                staff_loader.selectinload(Staff.administrator_profile),
                staff_loader.selectinload(Staff.teacher_profile),
                staff_loader.selectinload(Staff.psychologist_profile),
            )
            .where(Account.tax_code == tax_code)
        )
