from __future__ import annotations

from collections.abc import Collection, Sequence
from datetime import date

from sqlalchemy import select

from app.models.calendar_teacher_note import CalendarTeacherNote
from app.repositories.base import WritableRepository


class CalendarTeacherNoteRepository(WritableRepository[CalendarTeacherNote]):
    async def list_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarTeacherNote]:
        return (
            await self.session.scalars(
                select(CalendarTeacherNote)
                .where(
                    CalendarTeacherNote.date == day,
                    CalendarTeacherNote.band == band,
                )
                .order_by(CalendarTeacherNote.teacher_tax_code),
            )
        ).all()

    async def list_for_teacher(
        self,
        day: date,
        bands: Collection[str],
        teacher_tax_code: str,
    ) -> Sequence[CalendarTeacherNote]:
        if not bands:
            return []

        return (
            await self.session.scalars(
                select(CalendarTeacherNote)
                .where(
                    CalendarTeacherNote.date == day,
                    CalendarTeacherNote.band.in_(bands),
                    CalendarTeacherNote.teacher_tax_code == teacher_tax_code,
                )
                .order_by(CalendarTeacherNote.band),
            )
        ).all()
