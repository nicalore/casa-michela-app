from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.calendar_teacher_note import CalendarTeacherNote
from app.models.person import Person
from app.repositories.calendar_teacher_note_repository import (
    CalendarTeacherNoteRepository,
)
from app.repositories.person_repository import PersonRepository
from app.schemas.calendar_teacher_note import (
    CalendarTeacherNoteResponse,
    CalendarTeacherNotesReplace,
)
from app.schemas.person import PersonOption
from app.services.calendar_teacher_note_service import CalendarTeacherNoteService

router = APIRouter(
    prefix="/calendar-teacher-notes",
    tags=["calendar-teacher-notes"],
    dependencies=[Depends(require_role("ADMIN", "TEACHER"))],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _to_response(
    note: CalendarTeacherNote,
    people: dict[str, Person],
) -> CalendarTeacherNoteResponse:
    author = people.get(note.author_tax_code) if note.author_tax_code else None

    return CalendarTeacherNoteResponse(
        date=note.date,
        band=TimeBandEnum(note.band),
        teacher_tax_code=note.teacher_tax_code,
        text=note.text,
        author=PersonOption.model_validate(author) if author is not None else None,
        updated_at=note.updated_at,
    )


async def _to_responses(
    db: DbSession,
    notes: Sequence[CalendarTeacherNote],
) -> list[CalendarTeacherNoteResponse]:
    if not notes:
        return []

    people = await PersonRepository(db).get_options(
        note.author_tax_code for note in notes if note.author_tax_code is not None
    )

    return [_to_response(note, people) for note in notes]


def _service(db: DbSession) -> CalendarTeacherNoteService:
    return CalendarTeacherNoteService(CalendarTeacherNoteRepository(db))


# The administrator composing reads the band's notes; anyone else, their own
# in published bands only.
@router.get("/", response_model=list[CalendarTeacherNoteResponse])
async def list_notes(
    day: date,
    identity: CurrentIdentity,
    db: DbSession,
    band: TimeBandEnum | None = None,
) -> list[CalendarTeacherNoteResponse]:
    service = _service(db)

    if identity.reads_everything and band is not None:
        return await _to_responses(db, await service.list_for_band(day, str(band)))

    return await _to_responses(
        db,
        await service.list_own(identity, day, None if band is None else str(band)),
    )


@router.put(
    "/",
    response_model=list[CalendarTeacherNoteResponse],
    dependencies=_ADMIN_ONLY,
)
async def replace_notes(
    payload: CalendarTeacherNotesReplace,
    identity: CurrentIdentity,
    db: DbSession,
) -> list[CalendarTeacherNoteResponse]:
    return await _to_responses(db, await _service(db).replace(identity, payload))
