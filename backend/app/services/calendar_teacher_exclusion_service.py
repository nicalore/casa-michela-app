from collections.abc import Sequence
from datetime import date
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.models.calendar_teacher_exclusion import CalendarTeacherExclusion
from app.models.teacher import Teacher
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.calendar_teacher_exclusion_repository import (
    CalendarTeacherExclusionRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.schemas.calendar_teacher_exclusion import (
    CalendarTeacherExclusionCreate,
)
from app.services.lesson_guard import assert_band_claimed, assert_band_editable
from app.services.schedule_cascade import unassign

_EXCLUDE_ERROR: Final[str] = "Errore durante l'esclusione del docente."

_TEACHER_NOT_FOUND_ERROR: Final[str] = "Docente non trovato"


class CalendarTeacherExclusionService:
    def __init__(
        self,
        repository: CalendarTeacherExclusionRepository,
        lessons: LessonRepository,
    ) -> None:
        self.repository = repository
        self.lessons = lessons

    @property
    def session(self) -> AsyncSession:
        return self.repository.session

    # Same open/ownership checks every calendar write performs.
    async def _assert_mine_to_write(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> None:
        await assert_band_editable(self.session, day, band)
        await assert_band_claimed(self.session, identity, day, band)

    async def _assert_teaches(self, teacher_tax_code: str) -> None:
        found = await self.session.scalar(
            select(Teacher.tax_code).where(Teacher.tax_code == teacher_tax_code),
        )

        if found is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_TEACHER_NOT_FOUND_ERROR,
            )

    async def list_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarTeacherExclusion]:
        return await self.repository.list_for_band(day, band)

    # Excluding deletes the teacher's hours (their requests are replanned) but
    # hands attività back unassigned. Idempotent: excluding twice is a no-op.
    async def exclude(
        self,
        identity: IdentityContext,
        payload: CalendarTeacherExclusionCreate,
    ) -> tuple[CalendarTeacherExclusion, int, int]:
        band = str(payload.band)

        await self._assert_mine_to_write(identity, payload.date, band)
        await self._assert_teaches(payload.teacher_tax_code)

        standing = await self.repository.get(
            payload.date,
            band,
            payload.teacher_tax_code,
        )

        if standing is not None:
            return standing, 0, 0

        lessons = await self.lessons.list_for_teacher_in_band(
            payload.date,
            band,
            payload.teacher_tax_code,
        )

        for lesson in lessons:
            await self.session.delete(lesson)

        activities = await CalendarActivityRepository(
            self.session,
        ).find_assigned_to_teacher_in_band(
            payload.date,
            band,
            payload.teacher_tax_code,
        )

        # The cascade returns the activity's hours; the activity itself stays.
        await unassign(self.session, activities)

        exclusion = CalendarTeacherExclusion(
            date=payload.date,
            band=band,
            teacher_tax_code=payload.teacher_tax_code,
        )

        async with integrity_guard(self.session, _EXCLUDE_ERROR):
            await self.repository.create(exclusion)
            await self.repository.commit()
            await self.repository.refresh(exclusion)

        return exclusion, len(lessons), len(activities)

    # Removes only the exclusion row; idempotent.
    async def readmit(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
        teacher_tax_code: str,
    ) -> None:
        await self._assert_mine_to_write(identity, day, band)

        standing = await self.repository.get(day, band, teacher_tax_code)

        if standing is None:
            return

        await self.repository.delete(standing)
        await self.repository.commit()
