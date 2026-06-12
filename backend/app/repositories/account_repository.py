from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.account import Account


class AccountRepository:
    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.session = session

    async def get_by_username(
        self,
        username: str,
    ) -> Account | None:
        return await self.session.scalar(
            select(Account)
            .options(
                selectinload(Account.person),
            )
            .where(
                Account.username == username
            )
        )

    async def get_by_tax_code(
        self,
        tax_code: str,
    ) -> Account | None:
        return await self.session.scalar(
            select(Account)
            .options(
                selectinload(Account.person),
            )
            .where(
                Account.tax_code == tax_code
            )
        )

    async def save(
        self,
        account: Account,
    ) -> None:
        self.session.add(account)
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()