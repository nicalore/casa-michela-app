from sqlalchemy.ext.asyncio import AsyncSession


class SessionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session


# Services drive the transaction; the shared unit-of-work surface lives here.
# Read-only repositories extend SessionRepository instead.
class WritableRepository[T](SessionRepository):
    async def create(self, entity: T) -> None:
        self.session.add(entity)
        await self.session.flush()

    async def delete(self, entity: T) -> None:
        await self.session.delete(entity)
        await self.session.flush()

    async def refresh(self, entity: T) -> None:
        await self.session.refresh(entity)

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
