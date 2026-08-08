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
from app.models.presence import Presence
from app.models.student import Student
from app.repositories.presence_repository import PresenceRepository
from app.schemas.presence import PresenceCreate, PresenceUpdate
from app.services.opening_window import assert_within_opening

_ENTITY_LABEL: Final[str] = "la presenza"
_NOT_FOUND_ERROR: Final[str] = "Presenza non trovata"
_STUDENT_NOT_FOUND_ERROR: Final[str] = "Studente non trovato"
_FORBIDDEN_STUDENT_TAX_CODE_ERROR: Final[str] = (
    "Puoi gestire solo le presenze relative a te stesso o ai tuoi figli"
)
_FORBIDDEN_BOOKER_TAX_CODE_ERROR: Final[str] = "Puoi gestire solo le tue prenotazioni"
_CREATE_ERROR: Final[str] = "Errore durante la creazione della presenza."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_OUTSIDE_OPENING_ERROR: Final[str] = (
    "La presenza deve stare dentro l'apertura {mode}: {windows}."
)
_OVERLAP_ERROR: Final[str] = (
    "Lo studente ha già una presenza {mode} che si sovrappone a questo orario."
)
_CROSS_MODE_OVERLAP_ERROR: Final[str] = (
    "Lo studente è già {mode} in quelle ore: non può essere in due posti "
    "nello stesso momento."
)


class PresenceService:
    def __init__(self, repository: PresenceRepository) -> None:
        self.repository = repository

    # A pupil is here while the association is open, and reachable online while
    # it teaches online: either way the hours are given against one of the bands
    # it actually opens that day in that mode.
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

    # A pupil's day is made of stretches that do not run over each other: two
    # overlapping ones are the same hour promised twice. Across the two modes as
    # much as within one, because whoever is in the building from three to five
    # is not also at a screen from four to six.
    async def _assert_no_overlap(
        self,
        student_tax_code: str,
        target_date: date,
        mode: str,
        start_time: time,
        end_time: time,
        *,
        exclude_id: int | None,
    ) -> None:
        stmt = select(Presence).where(
            Presence.student_tax_code == student_tax_code,
            Presence.date == target_date,
            Presence.start_time < end_time,
            Presence.end_time > start_time,
        )

        if exclude_id is not None:
            stmt = stmt.where(Presence.id != exclude_id)

        clash = (await self.repository.session.execute(stmt)).scalars().first()

        if clash is None:
            return

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                _OVERLAP_ERROR.format(mode=opening_mode_label(mode))
                if clash.mode == mode
                else _CROSS_MODE_OVERLAP_ERROR.format(
                    mode=opening_mode_label(clash.mode)
                )
            ),
        )

    async def _assert_student_exists(self, student_tax_code: str) -> None:
        student = await self.repository.session.scalar(
            select(Student).where(Student.tax_code == student_tax_code)
        )

        if student is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_STUDENT_NOT_FOUND_ERROR,
            )

    def _resolve_student_tax_code_for_create(
        self,
        identity: IdentityContext,
        requested: str,
    ) -> str:
        if identity.is_admin:
            return requested

        if "STUDENT" in identity.roles and requested == identity.tax_code:
            return requested

        if "PARENT" in identity.roles and requested in identity.child_tax_codes:
            return requested

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_FORBIDDEN_STUDENT_TAX_CODE_ERROR,
        )

    def _resolve_booker_tax_code_for_create(
        self,
        identity: IdentityContext,
        payload_value: str | None,
    ) -> str:
        if payload_value is None:
            return identity.tax_code

        if not identity.is_admin and payload_value != identity.tax_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=_FORBIDDEN_BOOKER_TAX_CODE_ERROR,
            )

        return payload_value

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        student_tax_code: str | None,
        booker_tax_code: str | None,
        date_from: date | None,
        date_to: date | None,
    ) -> Sequence[Presence]:
        # A non-admin's booker_tax_code filter is always forced to
        # themselves; student_tax_code, if given, is passed through as-is
        # since it can only further narrow their own already-scoped results
        # (e.g. a parent filtering to one specific child).
        effective_booker_tax_code = (
            booker_tax_code if identity.is_admin else identity.tax_code
        )

        return await self.repository.list(
            student_tax_code=student_tax_code,
            booker_tax_code=effective_booker_tax_code,
            date_from=date_from,
            date_to=date_to,
        )

    async def get_owned_or_404(
        self,
        identity: IdentityContext,
        presence_id: int,
    ) -> Presence:
        owner_tax_code = None if identity.is_admin else identity.tax_code

        presence = await self.repository.get_by_id(
            presence_id,
            owner_tax_code=owner_tax_code,
        )

        if presence is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return presence

    # Validates, adds to the session and flushes, but does not commit: split out
    # of create() so a caller writing several rows in one transaction can reuse
    # every check without each one closing the transaction under it. Flushing,
    # rather than only adding, is what gives the presence its id, so bookings can
    # hang off it in the same go.
    async def prepare_create(
        self,
        identity: IdentityContext,
        payload: PresenceCreate,
    ) -> Presence:
        assert_within_booking_window(payload.date)

        student_tax_code = self._resolve_student_tax_code_for_create(
            identity,
            payload.student_tax_code,
        )
        booker_tax_code = self._resolve_booker_tax_code_for_create(
            identity,
            payload.booker_tax_code,
        )
        await self._assert_student_exists(student_tax_code)
        await self._assert_within_opening(
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            student_tax_code,
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
            exclude_id=None,
        )

        presence = Presence(
            student_tax_code=student_tax_code,
            booker_tax_code=booker_tax_code,
            date=payload.date,
            mode=payload.mode.value,
            start_time=payload.start_time,
            end_time=payload.end_time,
            # Explicitly marks the collection as loaded (empty): a brand-new
            # presence has no bookings yet, and this avoids an async lazy
            # load when the response is built right after.
            bookings=[],
        )

        await self.repository.create(presence)

        return presence

    async def create(
        self,
        identity: IdentityContext,
        payload: PresenceCreate,
    ) -> Presence:
        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            presence = await self.prepare_create(identity, payload)
            await self.repository.commit()

        return presence

    async def update(
        self,
        identity: IdentityContext,
        presence_id: int,
        payload: PresenceUpdate,
    ) -> Presence:
        presence = await self.get_owned_or_404(identity, presence_id)

        assert_not_stale(
            presence,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        if (
            payload.student_tax_code is not None
            and payload.student_tax_code != presence.student_tax_code
        ):
            if not identity.is_admin:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=_FORBIDDEN_STUDENT_TAX_CODE_ERROR,
                )

            await self._assert_student_exists(payload.student_tax_code)
            presence.student_tax_code = payload.student_tax_code

        if (
            payload.booker_tax_code is not None
            and payload.booker_tax_code != presence.booker_tax_code
        ):
            if not identity.is_admin:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=_FORBIDDEN_BOOKER_TAX_CODE_ERROR,
                )

            presence.booker_tax_code = payload.booker_tax_code

        if payload.date != presence.date:
            assert_within_booking_window(payload.date)

        await self._assert_within_opening(
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
        )
        await self._assert_no_overlap(
            presence.student_tax_code,
            payload.date,
            payload.mode,
            payload.start_time,
            payload.end_time,
            exclude_id=presence.id,
        )

        presence.date = payload.date
        presence.mode = payload.mode.value
        presence.start_time = payload.start_time
        presence.end_time = payload.end_time

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            await self.repository.commit()
            # updated_at is computed by the database on every UPDATE, so it is
            # expired the moment the statement lands and has to be read back
            # here: the response carries it, and reaching for it after the
            # request has left the session is IO in a place that cannot do any.
            await self.repository.refresh(presence)

        return presence

    async def delete(self, identity: IdentityContext, presence_id: int) -> None:
        presence = await self.get_owned_or_404(identity, presence_id)
        await self.repository.delete(presence)
        await self.repository.commit()
