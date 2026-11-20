from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.i18n import request_language
from app.core.integrity import integrity_guard
from app.core.labels import time_band_phrase
from app.core.optimistic_concurrency import assert_not_stale
from app.core.time_band import TimeBandEnum, band_bounds
from app.models.availability import Availability
from app.models.calendar_activity import CalendarActivity
from app.models.person import GenderEnum
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.person_repository import PersonRepository
from app.schemas.calendar_activity import (
    CalendarActivityAssignment,
    CalendarActivityCreate,
    CalendarActivityUpdate,
)
from app.services.bilingual import Bilingual
from app.services.calendar_freeze import assert_not_started
from app.services.lesson_guard import (
    assert_band_claimed,
    assert_band_editable,
    assert_teacher_not_excluded,
)
from app.services.teacher_band_mode import (
    BandHour,
    assert_one_mode,
    settle_teacher_band,
)
from app.services.teacher_occupancy import online_cannot_overlap_error

_ENTITY_LABEL: Final[Bilingual] = Bilingual(
    "l'attività",
    "the activity",
)
_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Attività non trovata",
    "Activity not found",
)
_CREATE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante la creazione dell'attività.",
    "Something went wrong while creating the activity.",
)
_UPDATE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante l'aggiornamento.",
    "Something went wrong while saving.",
)

_AVAILABILITY_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Disponibilità non trovata",
    "Availability not found",
)

_WRONG_DAY_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "La disponibilità del docente non è nel giorno dell'attività.",
        "The teacher's availability is not on the day of the activity.",
    ),
    GenderEnum.F: Bilingual(
        "La disponibilità della docente non è nel giorno dell'attività.",
        "The teacher's availability is not on the day of the activity.",
    ),
}

_OUTSIDE_BAND_ERROR: Final[Bilingual] = Bilingual(
    "L'attività appartiene al calendario {band} e deve svolgersi lì.",
    "The activity belongs to the {band} calendar and must take place there.",
)

_OUTSIDE_AVAILABILITY_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Fuori dalla disponibilità del docente ({start} - {end}).",
        "Outside the teacher's availability ({start} - {end}).",
    ),
    GenderEnum.F: Bilingual(
        "Fuori dalla disponibilità della docente ({start} - {end}).",
        "Outside the teacher's availability ({start} - {end}).",
    ),
}

_FROM_HOME_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "A quest'ora il docente non è disponibile in presenza.",
        "At this time the teacher is not available in person.",
    ),
    GenderEnum.F: Bilingual(
        "A quest'ora la docente non è disponibile in presenza.",
        "At this time the teacher is not available in person.",
    ),
}

_ACTIVITY_OVERLAP_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Il docente ha già un'altra attività a quest'ora.",
        "The teacher already has another activity at this time.",
    ),
    GenderEnum.F: Bilingual(
        "La docente ha già un'altra attività a quest'ora.",
        "The teacher already has another activity at this time.",
    ),
}


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

    async def _gender(self, teacher_tax_code: str) -> GenderEnum:
        return await PersonRepository(self.session).gender(teacher_tax_code)

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[CalendarActivity]:
        if identity.reads_everything:
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
                detail=_NOT_FOUND_ERROR.for_request(),
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
                detail=_AVAILABILITY_NOT_FOUND_ERROR.for_request(),
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
                detail=_OUTSIDE_BAND_ERROR.for_request().format(
                    band=time_band_phrase(band, request_language()),
                ),
            )

    async def _assert_within_availability(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
    ) -> None:
        if start_time < availability.start_time or end_time > availability.end_time:
            gender = await self._gender(availability.teacher_tax_code)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OUTSIDE_AVAILABILITY_ERRORS[gender].for_request().format(
                    start=_format_time(availability.start_time),
                    end=_format_time(availability.end_time),
                ),
            )

    # Activities happen at the association: hours offered online never hold one. Sent on
    # them, as an older window would, it goes on the presence hours that cover it.
    async def _in_the_building(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
    ) -> Availability:
        if availability.mode == "presence":
            return availability

        inside = await self.session.scalar(
            select(Availability).where(
                Availability.teacher_tax_code == availability.teacher_tax_code,
                Availability.date == availability.date,
                Availability.mode == "presence",
                Availability.start_time <= start_time,
                Availability.end_time >= end_time,
            ),
        )

        if inside is None:
            gender = await self._gender(availability.teacher_tax_code)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_FROM_HOME_ERRORS[gender].for_request(),
            )

        return inside

    async def _assert_free(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
        *,
        exclude_id: int,
    ) -> None:
        online = await self.repository.find_online_lesson_overlap(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
        )

        if online is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=online_cannot_overlap_error(),
            )

        busy = await self.repository.find_teacher_overlap(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
            exclude_id=exclude_id,
        )

        if busy is not None:
            gender = await self._gender(availability.teacher_tax_code)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_ACTIVITY_OVERLAP_ERRORS[gender].for_request(),
            )

    # Checks ordered to give the most useful refusal first.
    async def _validate(
        self,
        activity: CalendarActivity,
        assignment: CalendarActivityAssignment,
    ) -> Availability:
        availability = await self._availability_or_404(assignment.availability_id)

        if availability.date != activity.date:
            gender = await self._gender(availability.teacher_tax_code)

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_WRONG_DAY_ERRORS[gender].for_request(),
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
        await self._assert_within_availability(
            availability,
            assignment.start_time,
            assignment.end_time,
        )
        availability = await self._in_the_building(
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
        await assert_one_mode(
            self.session,
            availability.teacher_tax_code,
            activity.date,
            activity.band,
            BandHour(assignment.start_time, assignment.end_time, in_person=True),
            activity_id=activity.id,
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

        async with integrity_guard(self.session, _CREATE_ERROR.for_request()):
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
            entity_label=_ENTITY_LABEL.for_request(),
        )

        await self._assert_mine_to_write(identity, activity.date, activity.band)

        before = (activity.availability_id, activity.start_time, activity.end_time)
        began = activity.start_time

        teachers = (
            {activity.availability.teacher_tax_code} if activity.availability else set()
        )

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
            teachers.add(availability.teacher_tax_code)

        # Teacher and times are fixed once begun, nor can they be set to start before now.
        if (activity.availability_id, activity.start_time, activity.end_time) != before:
            assert_not_started(activity.date, began, activity.start_time)

        async with integrity_guard(self.session, _UPDATE_ERROR.for_request()):
            await self.session.flush()

            # Given or taken away, the activity may bring its teacher in or let them go.
            for teacher_tax_code in sorted(teachers):
                await settle_teacher_band(
                    self.session,
                    teacher_tax_code,
                    activity.date,
                    activity.band,
                )

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
        assert_not_started(activity.date, activity.start_time)

        teacher_tax_code = (
            activity.availability.teacher_tax_code if activity.availability else None
        )
        day = activity.date
        band = activity.band

        await self.repository.delete(activity)

        if teacher_tax_code is not None:
            await settle_teacher_band(self.session, teacher_tax_code, day, band)

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
