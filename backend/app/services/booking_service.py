from collections.abc import Sequence
from datetime import date
from typing import Final

from fastapi import HTTPException, status

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.models.association_subject import AssociationSubject
from app.models.booking import Booking
from app.models.booking_teacher_preference import (
    BookingTeacherPreference,
    TeacherPreferenceTypeEnum,
)
from app.models.presence import Presence
from app.models.subject_requested import SubjectRequested
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.booking import BookingBase, BookingCreate, BookingUpdate

_ENTITY_LABEL: Final[str] = "la prenotazione"
_NOT_FOUND_ERROR: Final[str] = "Prenotazione non trovata"
_PRESENCE_NOT_FOUND_ERROR: Final[str] = "Presenza non trovata"
_NO_SUBJECTS_ERROR: Final[str] = "Seleziona almeno una materia."
_INVALID_SUBJECTS_ERROR: Final[str] = (
    "Alcune materie selezionate non sono valide per questa materia ministeriale."
)
_UNKNOWN_TEACHERS_ERROR: Final[str] = "Alcuni docenti indicati non esistono: {codes}."
_UNKNOWN_ASSOCIATION_SUBJECT_ERROR: Final[str] = "La disciplina indicata non esiste."
_UNKNOWN_SERVICE_ERROR: Final[str] = 'Il servizio "{name}" non esiste.'
_CREATE_ERROR: Final[str] = "Errore durante la creazione della prenotazione."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."


class BookingService:
    def __init__(
        self,
        repository: BookingRepository,
        presence_repository: PresenceRepository,
    ) -> None:
        self.repository = repository
        self.presence_repository = presence_repository

    async def _get_authorized_presence(
        self,
        identity: IdentityContext,
        presence_id: int,
    ) -> Presence:
        owner_tax_code = None if identity.is_admin else identity.tax_code

        presence = await self.presence_repository.get_by_id(
            presence_id,
            owner_tax_code=owner_tax_code,
        )

        if presence is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_PRESENCE_NOT_FOUND_ERROR,
            )

        return presence

    async def resolve_subjects(
        self,
        ministry_subject_id: int | None,
        association_subject_ids: list[int],
    ) -> list[SubjectRequested]:
        # A lone-discipline or service request has no subjects to resolve: the
        # kind is told by the columns on the booking.
        if ministry_subject_id is None:
            return []

        if not association_subject_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NO_SUBJECTS_ERROR,
            )

        unique_ids = list(dict.fromkeys(association_subject_ids))

        pairs = await self.repository.find_ministry_association_subjects(
            ministry_subject_id,
            unique_ids,
        )

        if len(pairs) != len(unique_ids):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_INVALID_SUBJECTS_ERROR,
            )

        return [
            SubjectRequested(
                ministry_subject_id=pair.ministry_subject_id,
                association_subject_id=pair.association_subject_id,
                # Set directly from the already-loaded pair rather than left
                # to lazy-load: SQLAlchemy's async extension can't lazy-load
                # relationships outside of an explicit await.
                ministry_association_subject=pair,
            )
            for pair in pairs
        ]

    # Turns the two lists of tax codes into rows, checking they name teachers.
    # Existence only: a pupil may name a teacher who does not teach that subject,
    # or who has not offered that day. Which of the named ones the hour actually
    # goes to is the timetable's business.
    async def resolve_teacher_preferences(
        self,
        preferred_tax_codes: list[str],
        not_preferred_tax_codes: list[str],
    ) -> list[BookingTeacherPreference]:
        named = [*preferred_tax_codes, *not_preferred_tax_codes]

        if not named:
            return []

        existing = await self.repository.find_existing_teacher_tax_codes(named)
        missing = [tax_code for tax_code in named if tax_code not in existing]

        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_UNKNOWN_TEACHERS_ERROR.format(codes=", ".join(missing)),
            )

        return [
            BookingTeacherPreference(
                teacher_tax_code=tax_code,
                preference_type=preference_type,
            )
            for tax_codes, preference_type in (
                (preferred_tax_codes, TeacherPreferenceTypeEnum.PREFERRED),
                (not_preferred_tax_codes, TeacherPreferenceTypeEnum.NOT_PREFERRED),
            )
            for tax_code in tax_codes
        ]

    # A validated Booking hung off a presence, not yet added to the session. It
    # takes the presence as an object rather than an id: the caller already holds
    # it and has already been authorized on it, so re-selecting it here would be
    # a second query answering a question already answered.
    async def build_for_presence(
        self,
        presence: Presence,
        payload: BookingBase,
    ) -> Booking:
        association_subject = await self._resolve_request_target(payload)

        return Booking(
            presence=presence,
            duration=payload.duration,
            tags=payload.tags,
            topic=payload.topic,
            notes=payload.notes,
            association_subject_id=payload.association_subject_id,
            # Set from the row just loaded rather than left to lazy-load: the
            # response reads it right after, and SQLAlchemy's async extension
            # cannot lazy-load outside an explicit await.
            association_subject=association_subject,
            service_name=payload.service_name,
            subjects_requested=await self.resolve_subjects(
                payload.ministry_subject_id,
                payload.association_subject_ids,
            ),
            teacher_preferences=await self.resolve_teacher_preferences(
                payload.preferred_teacher_tax_codes,
                payload.not_preferred_teacher_tax_codes,
            ),
        )

    # Checks that the requested discipline or service exists, and returns the
    # loaded discipline. Without it, a wrong id or name would come out as a
    # foreign key violation: a generic 400 instead of a message saying what is
    # missing.
    async def _resolve_request_target(
        self,
        payload: BookingBase,
    ) -> AssociationSubject | None:
        association_subject: AssociationSubject | None = None

        if payload.association_subject_id is not None:
            association_subject = await self.repository.find_association_subject(
                payload.association_subject_id
            )

            if association_subject is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_UNKNOWN_ASSOCIATION_SUBJECT_ERROR,
                )

        if payload.service_name is not None:
            found_service = await self.repository.find_service(payload.service_name)

            if found_service is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_UNKNOWN_SERVICE_ERROR.format(name=payload.service_name),
                )

        return association_subject

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        presence_id: int | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Booking]:
        owner_tax_code = None if identity.is_admin else identity.tax_code

        return await self.repository.list(
            owner_tax_code=owner_tax_code,
            presence_id=presence_id,
            date_from=date_from,
            date_to=date_to,
        )

    async def get_owned_or_404(
        self,
        identity: IdentityContext,
        booking_id: int,
    ) -> Booking:
        owner_tax_code = None if identity.is_admin else identity.tax_code

        booking = await self.repository.get_by_id(
            booking_id,
            owner_tax_code=owner_tax_code,
        )

        if booking is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return booking

    async def create(
        self,
        identity: IdentityContext,
        payload: BookingCreate,
    ) -> Booking:
        presence = await self._get_authorized_presence(identity, payload.presence_id)
        booking = await self.build_for_presence(presence, payload)

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            await self.repository.create(booking)
            await self.repository.commit()

        return booking

    async def update(
        self,
        identity: IdentityContext,
        booking_id: int,
        payload: BookingUpdate,
    ) -> Booking:
        booking = await self.get_owned_or_404(identity, booking_id)

        assert_not_stale(
            booking,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        if (
            payload.presence_id is not None
            and payload.presence_id != booking.presence_id
        ):
            # Reassigning to a different presence is allowed for any caller
            # authorized on the *new* presence too, not just admins: it is a
            # resource reference to re-verify, not an identity field.
            new_presence = await self._get_authorized_presence(
                identity,
                payload.presence_id,
            )
            booking.presence = new_presence

        booking.association_subject = await self._resolve_request_target(payload)

        booking.duration = payload.duration
        booking.tags = payload.tags
        booking.topic = payload.topic
        booking.notes = payload.notes
        booking.association_subject_id = payload.association_subject_id
        booking.service_name = payload.service_name
        booking.subjects_requested = await self.resolve_subjects(
            payload.ministry_subject_id,
            payload.association_subject_ids,
        )
        booking.teacher_preferences = await self.resolve_teacher_preferences(
            payload.preferred_teacher_tax_codes,
            payload.not_preferred_teacher_tax_codes,
        )

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            await self.repository.commit()
            # updated_at is computed by the database on every UPDATE, so it is
            # expired the moment the statement lands and has to be read back
            # here: the response carries it, and reaching for it after the
            # request has left the session is IO in a place that cannot do any.
            await self.repository.refresh(booking)

        return booking

    async def delete(self, identity: IdentityContext, booking_id: int) -> None:
        booking = await self.get_owned_or_404(identity, booking_id)
        await self.repository.delete(booking)
        await self.repository.commit()
