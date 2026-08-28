from sqlalchemy import select

from app.models.school import School
from app.repositories.base import SessionRepository


class SchoolRepository(SessionRepository):
    # None for an id that no longer exists: the enrollment form prints that
    # cell blank rather than failing over a school someone deleted.
    async def get_name(self, school_id: int) -> str | None:
        return await self.session.scalar(
            select(School.name).where(School.id == school_id)
        )
