from __future__ import annotations

from collections.abc import Sequence
from datetime import date, time

from sqlalchemy import Select, select
from sqlalchemy.orm import selectinload

from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.repositories.base import WritableRepository

_EAGER_LOADER = (selectinload(CalendarActivity.availability),)


# Correlated on CalendarActivity; EXISTS so unassigned activities match nobody.
def _given_to(teacher_tax_code: str) -> Select[tuple[int]]:
    return (
        select(Availability.id)
        .where(
            Availability.id == CalendarActivity.availability_id,
            Availability.teacher_tax_code == teacher_tax_code,
        )
        .exists()
    )


class CalendarActivityRepository(WritableRepository[CalendarActivity]):
    def _ordered(self, stmt: Select[tuple[CalendarActivity]]):  # noqa: ANN202
        # Stable order; unassigned rows (null start_time) sort last.
        return stmt.options(*_EAGER_LOADER).order_by(
            CalendarActivity.date,
            CalendarActivity.start_time.nulls_last(),
            CalendarActivity.id,
        )

    async def list(
        self,
        *,
        date_from: date | None = None,
        date_to: date | None = None,
        teacher_tax_code: str | None = None,
        published_only: bool = False,
    ) -> Sequence[CalendarActivity]:
        stmt = self._ordered(select(CalendarActivity))

        if date_from is not None:
            stmt = stmt.where(CalendarActivity.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(CalendarActivity.date <= date_to)

        if teacher_tax_code is not None:
            stmt = stmt.where(_given_to(teacher_tax_code))

        if published_only:
            stmt = stmt.where(
                select(CalendarPublication.date)
                .where(
                    CalendarPublication.date == CalendarActivity.date,
                    CalendarPublication.band == CalendarActivity.band,
                )
                .exists(),
            )

        return (await self.session.scalars(stmt)).all()

    async def get_by_id(self, activity_id: int) -> CalendarActivity | None:
        return await self.session.scalar(
            select(CalendarActivity)
            .options(*_EAGER_LOADER)
            .where(CalendarActivity.id == activity_id),
        )

    async def list_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarActivity]:
        return (
            await self.session.scalars(
                self._ordered(
                    select(CalendarActivity).where(
                        CalendarActivity.date == day,
                        CalendarActivity.band == band,
                    ),
                ),
            )
        ).all()

    async def find_unassigned_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarActivity]:
        return (
            await self.session.scalars(
                select(CalendarActivity)
                .where(
                    CalendarActivity.date == day,
                    CalendarActivity.band == band,
                    CalendarActivity.availability_id.is_(None),
                )
                .order_by(CalendarActivity.id),
            )
        ).all()

    async def find_assigned_to_teacher_in_band(
        self,
        day: date,
        band: str,
        teacher_tax_code: str,
    ) -> Sequence[CalendarActivity]:
        return (
            await self.session.scalars(
                select(CalendarActivity)
                .options(*_EAGER_LOADER)
                .where(
                    CalendarActivity.date == day,
                    CalendarActivity.band == band,
                    _given_to(teacher_tax_code),
                )
                .order_by(CalendarActivity.start_time, CalendarActivity.id),
            )
        ).all()

    async def find_for_availability(
        self,
        availability_id: int,
    ) -> Sequence[CalendarActivity]:
        return (
            await self.session.scalars(
                select(CalendarActivity)
                .where(CalendarActivity.availability_id == availability_id)
                .order_by(CalendarActivity.start_time),
            )
        ).all()

    # Overlap is checked across the whole day, not just within the band.
    async def find_teacher_overlap(
        self,
        *,
        teacher_tax_code: str,
        day: date,
        start_time: time,
        end_time: time,
        exclude_id: int | None = None,
    ) -> CalendarActivity | None:
        stmt = (
            select(CalendarActivity)
            .join(Availability, Availability.id == CalendarActivity.availability_id)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                CalendarActivity.date == day,
                CalendarActivity.start_time < end_time,
                CalendarActivity.end_time > start_time,
            )
        )

        if exclude_id is not None:
            stmt = stmt.where(CalendarActivity.id != exclude_id)

        return await self.session.scalar(stmt)

    async def find_lesson_overlap(
        self,
        *,
        teacher_tax_code: str,
        day: date,
        start_time: time,
        end_time: time,
    ) -> Lesson | None:
        return await self.session.scalar(
            select(Lesson)
            .join(Availability, Availability.id == Lesson.availability_id)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                Lesson.date == day,
                Lesson.start_time < end_time,
                Lesson.end_time > start_time,
            ),
        )
