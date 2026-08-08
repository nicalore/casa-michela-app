from __future__ import annotations

from collections.abc import Sequence
from datetime import date

from sqlalchemy import select

from app.models.availability import Availability
from app.repositories.base import WritableRepository


class AvailabilityRepository(WritableRepository[Availability]):
    async def list(
        self,
        *,
        teacher_tax_code: str | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Availability]:
        stmt = select(Availability).order_by(
            Availability.date,
            Availability.start_time,
        )

        if teacher_tax_code is not None:
            stmt = stmt.where(Availability.teacher_tax_code == teacher_tax_code)

        if date_from is not None:
            stmt = stmt.where(Availability.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(Availability.date <= date_to)

        return (await self.session.execute(stmt)).scalars().all()

    async def get_by_id(
        self,
        availability_id: int,
        *,
        owner_tax_code: str | None,
    ) -> Availability | None:
        stmt = select(Availability).where(Availability.id == availability_id)

        if owner_tax_code is not None:
            stmt = stmt.where(Availability.teacher_tax_code == owner_tax_code)

        return await self.session.scalar(stmt)
