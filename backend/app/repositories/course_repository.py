from sqlalchemy import select

from app.models.course import Course
from app.repositories.base import SessionRepository


class CourseRepository(SessionRepository):
    # None for a course without a listed price: the form prints that cell
    # blank rather than inventing a figure.
    async def get_cost(self, name: str) -> str | None:
        return await self.session.scalar(
            select(Course.cost).where(Course.name == name)
        )
