from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.account import Account
from app.models.member import Member
from app.models.person import Person
from app.models.staff import Staff


class IdentityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_account_identity(self, tax_code: str) -> Account | None:
        person_loader = selectinload(Account.person)
        member_loader = person_loader.selectinload(Person.member_profile)
        staff_loader = member_loader.selectinload(Member.staff_profile)

        return await self.session.scalar(
            select(Account)
            .options(
                person_loader.selectinload(Person.parent_profile),
                member_loader.selectinload(Member.student_profile),
                member_loader.selectinload(Member.course_participant_profile),
                staff_loader.selectinload(Staff.administrator_profile),
                staff_loader.selectinload(Staff.teacher_profile),
                staff_loader.selectinload(Staff.psychologist_profile),
            )
            .where(Account.tax_code == tax_code)
        )