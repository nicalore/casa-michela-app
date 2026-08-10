from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select

from app.api.rbac import IdentityContext
from app.core.booking_window import assert_within_booking_window
from app.core.integrity import integrity_guard
from app.core.labels import opening_mode_label
from app.core.optimistic_concurrency import assert_not_stale
from app.models.availability import Availability
from app.models.teacher import Teacher
from app.repositories.availability_repository import AvailabilityRepository
from app.schemas.availability import AvailabilityCreate, AvailabilityUpdate
from app.services.lesson_guard import (
    assert_availability_not_scheduled,
    assert_day_has_no_published_lessons,
    find_availability_lessons,
)
from app.services.opening_window import assert_within_opening

_ENTITY_LABEL: Final[str] = "le disponibilità"
_NOT_FOUND_ERROR: Final[str] = "Disponibilità non trovata"
_TEACHER_NOT_FOUND_ERROR: Final[str] = "Docente non trovato"
_FORBIDDEN_TEACHER_TAX_CODE_ERROR: Final[str] = "Puoi gestire solo le tue disponibilità"
_CREATE_ERROR: Final[str] = "Errore durante la creazione della disponibilità."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_OUTSIDE_OPENING_ERROR: Final[str] = (
    "La disponibilità deve stare dentro l'apertura {mode}: {windows}."
)
_OVERLAP_ERROR: Final[str] = (
    "Il docente ha già una disponibilità {mode} che si sovrappone a questo orario."
)

_LESSON_OUTSIDE_NEW_WINDOW_ERROR: Final[str] = (
    "Una lezione pianificata ({start} - {end}) resterebbe fuori dalla nuova "
    "disponibilità: spostala o rimuovila prima."
)


class AvailabilityService:
    def __init__(self, repository: AvailabilityRepository) -> None:
        self.repository = repository

    # An availability is an offer to be there while the association is open, so
    # it can only be given inside one of the bands it actually opens that day.
    async def _assert_within_opening(
        self,
        target_date: date,
        mode: str,
        start_time: time,
        end_time: time,
    ) -> None:
        await assert_within_opening(
            self.repository.session,
            target_date=target_date,
            mode=mode,
            start_time=start_time,
            end_time=end_time,
            outside_opening_error=_OUTSIDE_OPENING_ERROR,
        )

    # A teacher's day in one mode is made of stretches that do not run over each
    # other: two overlapping ones are the same hour offered twice.
    async def _assert_no_overlap(
        self,
        teacher_tax_code: str,
        target_date: date,
        mode: str,
        start_time: time,
        end_time: time,
        *,
        exclude_id: int | None,
    ) -> None:
        stmt = select(Availability).where(
            Availability.teacher_tax_code == teacher_tax_code,
            Availability.date == target_date,
            Availability.mode == mode,
            Availability.start_time < end_time,
            Availability.end_time > start_time,
        )

        if exclude_id is not None:
            stmt = stmt.where(Availability.id != exclude_id)

        if (await self.repository.session.execute(stmt)).scalars().first() is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OVERLAP_ERROR.format(mode=opening_mode_label(mode)),
            )

    # The calendar is kept as a record, so an availability with lessons on it can
    # no longer move day or mode: the composite foreign key restricts, and the
    # database would refuse anyway — but with an integrity error and a generic
    # message instead of the sentence below.
    #
    # Narrowing the hours is the one case the database cannot see, and the one
    # that matters most: a lesson left outside the new window would still point
    # at a valid availability while no longer being inside it.
    async def _assert_lessons_still_fit(
        self,
        availability: Availability,
        payload: AvailabilityUpdate,
    ) -> None:
        lessons = await find_availability_lessons(
            self.repository.session,
            availability.id,
        )

        if not lessons:
            return

        if payload.date != availability.date or payload.mode.value != availability.mode:
            await assert_availability_not_scheduled(
                self.repository.session,
                availability.id,
            )

        for lesson in lessons:
            if (
                lesson.start_time < payload.start_time
                or lesson.end_time > payload.end_time
            ):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_LESSON_OUTSIDE_NEW_WINDOW_ERROR.format(
                        start=lesson.start_time.strftime("%H:%M"),
                        end=lesson.end_time.strftime("%H:%M"),
                    ),
                )

    async def _assert_teacher_exists(self, teacher_tax_code: str) -> None:
        teacher = await self.repository.session.scalar(
            select(Teacher).where(Teacher.tax_code == teacher_tax_code)
        )

        if teacher is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_TEACHER_NOT_FOUND_ERROR,
            )

    def _resolve_teacher_tax_code_for_create(
        self,
        identity: IdentityContext,
        payload_value: str | None,
    ) -> str:
        if payload_value is None:
            return identity.tax_code

        if not identity.is_admin and payload_value != identity.tax_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=_FORBIDDEN_TEACHER_TAX_CODE_ERROR,
            )

        return payload_value

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        teacher_tax_code: str | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Availability]:
        effective_teacher_tax_code = (
            teacher_tax_code if identity.is_admin else identity.tax_code
        )

        return await self.repository.list(
            teacher_tax_code=effective_teacher_tax_code,
            date_from=date_from,
            date_to=date_to,
        )

    async def get_owned_or_404(
        self,
        identity: IdentityContext,
        availability_id: int,
    ) -> Availability:
        owner_tax_code = None if identity.is_admin else identity.tax_code

        availability = await self.repository.get_by_id(
            availability_id,
            owner_tax_code=owner_tax_code,
        )

        if availability is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return availability

    async def create(
        self,
        identity: IdentityContext,
        payload: AvailabilityCreate,
    ) -> Availability:
        assert_within_booking_window(payload.date)

        teacher_tax_code = self._resolve_teacher_tax_code_for_create(
            identity,
            payload.teacher_tax_code,
        )
        await self._assert_teacher_exists(teacher_tax_code)
        await self._assert_within_opening(
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            teacher_tax_code,
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
            exclude_id=None,
        )

        availability = Availability(
            teacher_tax_code=teacher_tax_code,
            date=payload.date,
            mode=payload.mode.value,
            start_time=payload.start_time,
            end_time=payload.end_time,
        )

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            await self.repository.create(availability)
            await self.repository.commit()

        return availability

    async def update(
        self,
        identity: IdentityContext,
        availability_id: int,
        payload: AvailabilityUpdate,
    ) -> Availability:
        availability = await self.get_owned_or_404(identity, availability_id)

        assert_not_stale(
            availability,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        if (
            payload.teacher_tax_code is not None
            and payload.teacher_tax_code != availability.teacher_tax_code
        ):
            if not identity.is_admin:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=_FORBIDDEN_TEACHER_TAX_CODE_ERROR,
                )

            await self._assert_teacher_exists(payload.teacher_tax_code)
            availability.teacher_tax_code = payload.teacher_tax_code

        await assert_day_has_no_published_lessons(
            self.repository.session,
            availability.date,
        )
        await self._assert_lessons_still_fit(availability, payload)

        if payload.date != availability.date:
            assert_within_booking_window(payload.date)

        await self._assert_within_opening(
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            availability.teacher_tax_code,
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
            exclude_id=availability.id,
        )

        availability.date = payload.date
        availability.mode = payload.mode.value
        availability.start_time = payload.start_time
        availability.end_time = payload.end_time

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            await self.repository.commit()
            # updated_at is computed by the database on every UPDATE, so it is
            # expired the moment the statement lands and has to be read back
            # here: the response carries it, and reaching for it after the
            # request has left the session is IO in a place that cannot do any.
            await self.repository.refresh(availability)

        return availability

    # Refused for everybody, administrators included: there is no cascade left to
    # authorise. Whoever wants the availability back deletes its lessons first,
    # unpublishing the band if it has gone out.
    async def delete(self, identity: IdentityContext, availability_id: int) -> None:
        availability = await self.get_owned_or_404(identity, availability_id)

        await assert_day_has_no_published_lessons(
            self.repository.session,
            availability.date,
        )
        await assert_availability_not_scheduled(
            self.repository.session,
            availability.id,
        )

        await self.repository.delete(availability)
        await self.repository.commit()
