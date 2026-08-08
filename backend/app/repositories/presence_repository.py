from __future__ import annotations

from collections.abc import Sequence
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.booking import Booking
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.presence import Presence
from app.models.subject_requested import SubjectRequested
from app.repositories.base import WritableRepository

_BOOKINGS_LOADER = selectinload(Presence.bookings).options(
    selectinload(Booking.subjects_requested).options(
        selectinload(SubjectRequested.ministry_association_subject).selectinload(
            MinistryAssociationSubject.association_subject
        )
    ),
    selectinload(Booking.teacher_preferences),
    selectinload(Booking.association_subject),
)


class PresenceRepository(WritableRepository[Presence]):
    async def list(
        self,
        *,
        student_tax_code: str | None,
        booker_tax_code: str | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Presence]:
        stmt = (
            select(Presence)
            .options(_BOOKINGS_LOADER)
            .order_by(
                Presence.date,
                Presence.start_time,
            )
        )

        if student_tax_code is not None:
            stmt = stmt.where(Presence.student_tax_code == student_tax_code)

        if booker_tax_code is not None:
            stmt = stmt.where(Presence.booker_tax_code == booker_tax_code)

        if date_from is not None:
            stmt = stmt.where(Presence.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(Presence.date <= date_to)

        return (await self.session.execute(stmt)).scalars().all()

    async def get_by_id(
        self,
        presence_id: int,
        *,
        owner_tax_code: str | None,
    ) -> Presence | None:
        stmt = (
            select(Presence).options(_BOOKINGS_LOADER).where(Presence.id == presence_id)
        )

        if owner_tax_code is not None:
            stmt = stmt.where(Presence.booker_tax_code == owner_tax_code)

        return await self.session.scalar(stmt)
