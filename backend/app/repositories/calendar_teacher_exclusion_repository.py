from __future__ import annotations

from collections.abc import Sequence
from datetime import date

from sqlalchemy import select

from app.models.calendar_teacher_exclusion import CalendarTeacherExclusion
from app.repositories.base import WritableRepository


class CalendarTeacherExclusionRepository(
    WritableRepository[CalendarTeacherExclusion],
):
    async def list_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarTeacherExclusion]:
        return (
            await self.session.scalars(
                select(CalendarTeacherExclusion)
                .where(
                    CalendarTeacherExclusion.date == day,
                    CalendarTeacherExclusion.band == band,
                )
                .order_by(CalendarTeacherExclusion.teacher_tax_code),
            )
        ).all()

    async def tax_codes_for_band(self, day: date, band: str) -> set[str]:
        return set(
            (
                await self.session.scalars(
                    select(CalendarTeacherExclusion.teacher_tax_code).where(
                        CalendarTeacherExclusion.date == day,
                        CalendarTeacherExclusion.band == band,
                    ),
                )
            ).all(),
        )

    async def get(
        self,
        day: date,
        band: str,
        teacher_tax_code: str,
    ) -> CalendarTeacherExclusion | None:
        return await self.session.scalar(
            select(CalendarTeacherExclusion).where(
                CalendarTeacherExclusion.date == day,
                CalendarTeacherExclusion.band == band,
                CalendarTeacherExclusion.teacher_tax_code == teacher_tax_code,
            ),
        )
