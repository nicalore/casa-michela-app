from collections.abc import Sequence
from datetime import date
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.models.calendar_teacher_note import CalendarTeacherNote
from app.models.teacher import Teacher
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.calendar_teacher_note_repository import (
    CalendarTeacherNoteRepository,
)
from app.schemas.calendar_teacher_note import CalendarTeacherNotesReplace
from app.services.bilingual import Bilingual
from app.services.lesson_guard import assert_band_claimed, assert_band_editable

_SAVE_ERROR: Final[Bilingual] = Bilingual(
    "Errore durante il salvataggio delle note.",
    "Something went wrong while saving the notes.",
)

_TEACHER_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Docente non trovato",
    "Teacher not found",
)


class CalendarTeacherNoteService:
    def __init__(self, repository: CalendarTeacherNoteRepository) -> None:
        self.repository = repository

    @property
    def session(self) -> AsyncSession:
        return self.repository.session

    async def list_for_band(
        self,
        day: date,
        band: str,
    ) -> Sequence[CalendarTeacherNote]:
        return await self.repository.list_for_band(day, band)

    # A teacher reads their own notes once the band is out, as with lessons.
    async def list_own(
        self,
        identity: IdentityContext,
        day: date,
        band: str | None,
    ) -> Sequence[CalendarTeacherNote]:
        published = await CalendarPublicationRepository(
            self.session,
        ).find_published_bands(day)

        bands = published if band is None else published & {band}

        return await self.repository.list_for_teacher(day, bands, identity.tax_code)

    async def _assert_teachers(self, tax_codes: set[str]) -> None:
        if not tax_codes:
            return

        found = set(
            (
                await self.session.scalars(
                    select(Teacher.tax_code).where(Teacher.tax_code.in_(tax_codes)),
                )
            ).all(),
        )

        if found != tax_codes:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_TEACHER_NOT_FOUND_ERROR.for_request(),
            )

    # Only while the band is being composed; the writer becomes the author of
    # every note whose text changes.
    async def replace(
        self,
        identity: IdentityContext,
        payload: CalendarTeacherNotesReplace,
    ) -> Sequence[CalendarTeacherNote]:
        band = str(payload.band)

        await assert_band_editable(self.session, payload.date, band)
        await assert_band_claimed(self.session, identity, payload.date, band)

        wanted = {
            entry.teacher_tax_code: entry.text
            for entry in payload.notes
            if entry.text is not None
        }

        await self._assert_teachers(set(wanted))

        current = {
            note.teacher_tax_code: note
            for note in await self.repository.list_for_band(payload.date, band)
        }

        async with integrity_guard(self.session, _SAVE_ERROR.for_request()):
            for tax_code, note in current.items():
                if tax_code not in wanted:
                    await self.repository.delete(note)

            for tax_code, text in wanted.items():
                note = current.get(tax_code)

                if note is None:
                    await self.repository.create(
                        CalendarTeacherNote(
                            date=payload.date,
                            band=band,
                            teacher_tax_code=tax_code,
                            text=text,
                            author_tax_code=identity.tax_code,
                        ),
                    )
                elif note.text != text:
                    note.text = text
                    note.author_tax_code = identity.tax_code

            await self.repository.commit()

        return await self.repository.list_for_band(payload.date, band)
