from datetime import UTC, datetime

from sqlalchemy import (
    select,
    update,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.refresh_token import (
    RefreshToken,
)


class RefreshTokenRepository:
    def __init__(
        self,
        session: AsyncSession,
    ) -> None:
        self.session = session

    async def save(
        self,
        refresh_token: RefreshToken,
    ) -> None:
        self.session.add(
            refresh_token
        )

        await self.session.flush()

    async def get_by_token_id(
        self,
        token_id: str,
    ) -> RefreshToken | None:
        return await self.session.scalar(
            select(RefreshToken).where(
                RefreshToken.token_id
                == token_id
            )
        )

    async def revoke(
        self,
        refresh_token: RefreshToken,
    ) -> None:
        refresh_token.revoked_at = (
            datetime.now(UTC)
        )

        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def delete(
    self,
    refresh_token: RefreshToken,
    ) -> None:
        await self.session.delete(
        refresh_token
    )

        await self.session.flush()

    async def revoke_all_for_account_except(
        self,
        account_tax_code: str,
        token_id: str,
        ) -> None:
        await self.session.execute(
            update(
                RefreshToken
            )
            .where(
                RefreshToken.account_tax_code
                == account_tax_code,
                RefreshToken.token_id
                != token_id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(
                revoked_at=datetime.now(
                    UTC
                ),
            )
        )

        await self.session.flush()

    