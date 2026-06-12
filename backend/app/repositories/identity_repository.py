from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.account import Account
from app.models.member import Member
from app.models.person import Person
from app.models.staff import Staff


class IdentityRepository:
    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.session = session

    async def get_account_identity(
        self,
        tax_code: str,
    ) -> Account | None:
        return await self.session.scalar(
            select(Account)
            .options(
                selectinload(
                    Account.person,
                ).selectinload(
                    Person.parent_profile,
                ),
                selectinload(
                    Account.person,
                )
                .selectinload(
                    Person.member_profile,
                )
                .selectinload(
                    Member.student_profile,
                ),
                selectinload(
                    Account.person,
                )
                .selectinload(
                    Person.member_profile,
                )
                .selectinload(
                    Member.course_participant_profile,
                ),
                selectinload(
                    Account.person,
                )
                .selectinload(
                    Person.member_profile,
                )
                .selectinload(
                    Member.staff_profile,
                )
                .selectinload(
                    Staff.administrator_profile,
                ),
                selectinload(
                    Account.person,
                )
                .selectinload(
                    Person.member_profile,
                )
                .selectinload(
                    Member.staff_profile,
                )
                .selectinload(
                    Staff.teacher_profile,
                ),
                selectinload(
                    Account.person,
                )
                .selectinload(
                    Person.member_profile,
                )
                .selectinload(
                    Member.staff_profile,
                )
                .selectinload(
                    Staff.psychologist_profile,
                ),
            )
            .where(Account.tax_code == tax_code)
        )
