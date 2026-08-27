from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.core.labels import time_band_label
from app.core.optimistic_concurrency import assert_not_stale
from app.core.time_band import TimeBandEnum, band_bounds
from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.schemas.calendar_activity import (
    CalendarActivityAssignment,
    CalendarActivityCreate,
    CalendarActivityUpdate,
)
from app.services.lesson_guard import (
    assert_band_claimed,
    assert_band_editable,
    assert_teacher_not_excluded,
)

_ENTITY_LABEL: Final[str] = "l'attività"
_NOT_FOUND_ERROR: Final[str] = "Attività non trovata"
_CREATE_ERROR: Final[str] = "Errore durante la creazione dell'attività."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_AVAILABILITY_NOT_FOUND_ERROR: Final[str] = "Disponibilità non trovata"

_WRONG_DAY_ERROR: Final[str] = (
    "La disponibilità del docente non è nel giorno dell'attività."
)

_OUTSIDE_BAND_ERROR: Final[str] = (
    "L'attività appartiene al calendario del {band} e deve svolgersi lì."
)

_OUTSIDE_AVAILABILITY_ERROR: Final[str] = (
    "Fuori dalla disponibilità del docente ({start} - {end})."
)

_LESSON_OVERLAP_ERROR: Final[str] = (
    "Il docente ha già una lezione a quest'ora."
)

_ACTIVITY_OVERLAP_ERROR: Final[str] = (
    "Il docente ha già un'altra attività a quest'ora."
)


def _format_time(value: time) -> str:
    return value.strftime("%H:%M")


# Pupils and parents see no activities; a teacher sees their own only once
# the calendar has gone out (same rule as lessons).
class CalendarActivityService:
    def __init__(self, repository: CalendarActivityRepository) -> None:
        self.repository = repository

    @property
    def session(self) -> AsyncSession:
        return self.repository.session

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[CalendarActivity]:
        if identity.is_admin:
            return await self.repository.list(date_from=date_from, date_to=date_to)

        if "TEACHER" not in identity.roles:
            return []

        return await self.repository.list(
            date_from=date_from,
            date_to=date_to,
            teacher_tax_code=identity.tax_code,
            published_only=True,
        )

    async def get_or_404(self, activity_id: int) -> CalendarActivity:
        activity = await self.repository.get_by_id(activity_id)

        if activity is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return activity

    # Same open/ownership checks every calendar write performs; the band is
    # the activity's own and does not move.
    async def _assert_mine_to_write(
        self,
        identity: IdentityContext,
        day: date,
        band: str,
    ) -> None:
        await assert_band_editable(self.session, day, band)
        await assert_band_claimed(self.session, identity, day, band)

    async def _availability_or_404(self, availability_id: int) -> Availability:
        availability = await self.session.scalar(
            select(Availability).where(Availability.id == availability_id),
        )

        if availability is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_AVAILABILITY_NOT_FOUND_ERROR,
            )

        return availability

    def _assert_within_band(
        self,
        band: str,
        start_time: time,
        end_time: time,
    ) -> None:
        band_start, band_end = band_bounds(TimeBandEnum(band))

        if start_time < band_start or end_time > band_end:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OUTSIDE_BAND_ERROR.format(
                    band=time_band_label(band).lower(),
                ),
            )

    def _assert_within_availability(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
    ) -> None:
        if start_time < availability.start_time or end_time > availability.end_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OUTSIDE_AVAILABILITY_ERROR.format(
                    start=_format_time(availability.start_time),
                    end=_format_time(availability.end_time),
                ),
            )

    async def _assert_free(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
        *,
        exclude_id: int,
    ) -> None:
        teaching = await self.repository.find_lesson_overlap(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
        )

        if teaching is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_LESSON_OVERLAP_ERROR,
            )

        busy = await self.repository.find_teacher_overlap(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
            exclude_id=exclude_id,
        )

        if busy is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_ACTIVITY_OVERLAP_ERROR,
            )

    # Checks ordered to give the most useful refusal first.
    async def _validate(
        self,
        activity: CalendarActivity,
        assignment: CalendarActivityAssignment,
    ) -> Availability:
        availability = await self._availability_or_404(assignment.availability_id)

        if availability.date != activity.date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_WRONG_DAY_ERROR,
            )

        await assert_teacher_not_excluded(
            self.session,
            activity.date,
            activity.band,
            availability.teacher_tax_code,
        )

        self._assert_within_band(
            activity.band,
            assignment.start_time,
            assignment.end_time,
        )
        self._assert_within_availability(
            availability,
            assignment.start_time,
            assignment.end_time,
        )
        await self._assert_free(
            availability,
            assignment.start_time,
            assignment.end_time,
            exclude_id=activity.id,
        )

        return availability

    async def create(
        self,
        identity: IdentityContext,
        payload: CalendarActivityCreate,
    ) -> CalendarActivity:
        band = str(payload.band)

        await self._assert_mine_to_write(identity, payload.date, band)

        activity = CalendarActivity(
            date=payload.date,
            band=band,
            name=payload.name,
            description=payload.description,
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(activity)
            await self.repository.commit()

        return await self.get_or_404(activity.id)

    async def update(
        self,
        identity: IdentityContext,
        activity_id: int,
        payload: CalendarActivityUpdate,
    ) -> CalendarActivity:
        activity = await self.get_or_404(activity_id)

        assert_not_stale(
            activity,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        await self._assert_mine_to_write(identity, activity.date, activity.band)

        activity.name = payload.name
        activity.description = payload.description

        assignment = payload.assignment

        if assignment is None:
            self._unassign(activity)
        else:
            availability = await self._validate(activity, assignment)

            activity.availability_id = availability.id
            activity.teacher_mode = availability.mode
            activity.start_time = assignment.start_time
            activity.end_time = assignment.end_time

        async with integrity_guard(self.session, _UPDATE_ERROR):
            await self.repository.commit()

        # Written by hand: nulling the relationship would also null the date
        # its key carries; the stale teacher is dropped and re-fetched below.
        self.session.expire(activity, ["availability"])

        return await self.get_or_404(activity.id)

    @staticmethod
    def _unassign(activity: CalendarActivity) -> None:
        activity.availability_id = None
        activity.teacher_mode = None
        activity.start_time = None
        activity.end_time = None

    async def delete(self, identity: IdentityContext, activity_id: int) -> None:
        activity = await self.get_or_404(activity_id)

        await self._assert_mine_to_write(identity, activity.date, activity.band)

        await self.repository.delete(activity)
        await self.repository.commit()

    # An activity in a settled band is read, not moved.
    async def settled_bands(
        self,
        activities: Sequence[CalendarActivity],
    ) -> set[tuple[date, str]]:
        if not activities:
            return set()

        return await CalendarPublicationRepository(self.session).find_settled_pairs(
            {(activity.date, activity.band) for activity in activities},
        )
