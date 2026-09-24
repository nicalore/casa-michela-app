from datetime import UTC, datetime

from sqlalchemy import exists, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.refresh_token import RefreshToken, TokenTypeEnum


class RefreshTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def save(self, refresh_token: RefreshToken) -> None:
        self.session.add(refresh_token)
        await self.session.flush()

    # Locked when rotating: two renewals of one token run one after the other.
    async def get_by_token_id(
        self,
        token_id: str,
        for_update: bool = False,
    ) -> RefreshToken | None:
        statement = select(RefreshToken).where(RefreshToken.token_id == token_id)

        if for_update:
            statement = statement.with_for_update()

        return await self.session.scalar(statement)

    async def revoke(self, refresh_token: RefreshToken) -> None:
        refresh_token.revoked_at = datetime.now(UTC)
        await self.session.flush()

    async def revoke_all_for_account_except(
        self,
        account_tax_code: str,
        token_id: str,
    ) -> None:
        await self.session.execute(
            update(RefreshToken)
            .where(
                RefreshToken.account_tax_code == account_tax_code,
                RefreshToken.token_id != token_id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )

        await self.session.flush()

    # Sessions only: a pending reset link must survive, being how a locked-out
    # user gets back in.
    async def revoke_all_for_account(self, account_tax_code: str) -> None:
        await self.session.execute(
            update(RefreshToken)
            .where(
                RefreshToken.account_tax_code == account_tax_code,
                RefreshToken.token_type == TokenTypeEnum.REFRESH,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )

        await self.session.flush()

    # Rotation revokes the previous token, so one live row stands for each session.
    async def get_active_sessions(
        self,
        account_tax_code: str,
        now: datetime,
    ) -> list[RefreshToken]:
        result = await self.session.scalars(
            select(RefreshToken)
            .where(
                RefreshToken.account_tax_code == account_tax_code,
                RefreshToken.token_type == TokenTypeEnum.REFRESH,
                RefreshToken.revoked_at.is_(None),
                RefreshToken.expires_at > now,
            )
            .order_by(RefreshToken.created_at.desc())
        )

        return list(result)

    async def session_is_live(
        self,
        account_tax_code: str,
        session_id: str,
        now: datetime,
    ) -> bool:
        live = await self.session.scalar(
            select(
                exists().where(
                    RefreshToken.account_tax_code == account_tax_code,
                    RefreshToken.session_id == session_id,
                    RefreshToken.token_type == TokenTypeEnum.REFRESH,
                    RefreshToken.revoked_at.is_(None),
                    RefreshToken.expires_at > now,
                )
            )
        )

        return bool(live)

    async def revoke_session(self, account_tax_code: str, session_id: str) -> int:
        result = await self.session.execute(
            update(RefreshToken)
            .where(
                RefreshToken.account_tax_code == account_tax_code,
                RefreshToken.session_id == session_id,
                RefreshToken.token_type == TokenTypeEnum.REFRESH,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )

        await self.session.flush()

        return result.rowcount

    async def delete(self, refresh_token: RefreshToken) -> None:
        await self.session.delete(refresh_token)
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()