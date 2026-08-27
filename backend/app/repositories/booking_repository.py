from __future__ import annotations

from collections.abc import Iterable, Sequence
from datetime import date, time

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.association_subject import AssociationSubject
from app.models.booking import Booking
from app.models.lesson_booking import LessonBooking
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.presence import Presence
from app.models.service import Service
from app.models.subject_requested import SubjectRequested
from app.models.teacher import Teacher
from app.repositories.base import WritableRepository

# Public: the lessons read bookings the same way.
BOOKING_EAGER_LOADER = (
    selectinload(Booking.presence),
    selectinload(Booking.subjects_requested)
    .selectinload(SubjectRequested.ministry_association_subject)
    .selectinload(MinistryAssociationSubject.association_subject),
    selectinload(Booking.teacher_preferences),
    selectinload(Booking.association_subject),
)


class BookingRepository(WritableRepository[Booking]):
    async def list(
        self,
        *,
        owner_tax_code: str | None,
        presence_id: int | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Booking]:
        stmt = (
            select(Booking)
            .join(Booking.presence)
            .options(*BOOKING_EAGER_LOADER)
            .order_by(Presence.date, Presence.start_time)
        )

        if owner_tax_code is not None:
            stmt = stmt.where(Presence.booker_tax_code == owner_tax_code)

        if presence_id is not None:
            stmt = stmt.where(Booking.presence_id == presence_id)

        if date_from is not None:
            stmt = stmt.where(Presence.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(Presence.date <= date_to)

        return (await self.session.execute(stmt)).scalars().all()

    # Students of the band whose requests no lesson teaches anywhere in the
    # day: the requests nobody has looked at.
    async def find_unplanned_students(
        self,
        day: date,
        start_time: time,
        end_time: time,
    ) -> Sequence[str]:
        planned = (
            select(LessonBooking.booking_id)
            .where(LessonBooking.booking_id == Booking.id)
            .exists()
        )

        rows = await self.session.scalars(
            select(Presence.student_tax_code)
            .join(Booking.presence)
            .where(
                Presence.date == day,
                Presence.start_time < end_time,
                Presence.end_time > start_time,
                ~planned,
            )
            .distinct(),
        )

        return list(rows)

    async def get_by_id(
        self,
        booking_id: int,
        *,
        owner_tax_code: str | None,
    ) -> Booking | None:
        stmt = (
            select(Booking)
            .join(Booking.presence)
            .options(*BOOKING_EAGER_LOADER)
            .where(Booking.id == booking_id)
        )

        if owner_tax_code is not None:
            stmt = stmt.where(Presence.booker_tax_code == owner_tax_code)

        return await self.session.scalar(stmt)

    async def find_ministry_association_subjects(
        self,
        ministry_subject_id: int,
        association_subject_ids: list[int],
    ) -> Sequence[MinistryAssociationSubject]:
        stmt = (
            select(MinistryAssociationSubject)
            .options(selectinload(MinistryAssociationSubject.association_subject))
            .where(
                MinistryAssociationSubject.ministry_subject_id == ministry_subject_id,
                MinistryAssociationSubject.association_subject_id.in_(
                    association_subject_ids
                ),
            )
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def find_existing_teacher_tax_codes(
        self,
        tax_codes: Iterable[str],
    ) -> set[str]:
        unique = set(tax_codes)

        if not unique:
            return set()

        # One query for both sides: only existence of the named teachers matters.
        rows = await self.session.scalars(
            select(Teacher.tax_code).where(Teacher.tax_code.in_(unique))
        )

        return set(rows)

    async def find_association_subject(
        self,
        association_subject_id: int,
    ) -> AssociationSubject | None:
        return await self.session.scalar(
            select(AssociationSubject).where(
                AssociationSubject.id == association_subject_id
            )
        )

    async def find_service(self, name: str) -> Service | None:
        return await self.session.scalar(
            select(Service).where(Service.name == name)
        )
