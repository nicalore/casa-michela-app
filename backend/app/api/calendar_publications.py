from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.calendar_publication import CalendarPublication
from app.models.person import Person
from app.repositories.calendar_publication_repository import (
    CalendarPublicationRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.schemas.calendar_publication import (
    CalendarDraftClosed,
    CalendarDraftDiscarded,
    CalendarPublicationCreate,
    CalendarPublicationResponse,
)
from app.schemas.person import PersonOption
from app.services.calendar_publication_service import CalendarPublicationService

router = APIRouter(
    prefix="/calendar-publications",
    tags=["calendar-publications"],
    dependencies=[Depends(require_role("ADMIN"))],
)


def _to_response(
    publication: CalendarPublication,
    people: dict[str, Person],
    warnings: list[str],
    *,
    has_changes: bool = False,
) -> CalendarPublicationResponse:
    publisher = (
        people.get(publication.published_by)
        if publication.published_by is not None
        else None
    )

    return CalendarPublicationResponse(
        date=publication.date,
        band=TimeBandEnum(publication.band),
        published_at=publication.published_at,
        published_by=publication.published_by,
        publisher=(
            PersonOption.model_validate(publisher) if publisher is not None else None
        ),
        is_draft=publication.draft_snapshot is not None,
        has_changes=has_changes,
        warnings=warnings,
    )


async def _to_responses(
    db: DbSession,
    publications: Sequence[CalendarPublication],
    *,
    warnings: list[str] | None = None,
    changed: set[tuple[date, str]] | None = None,
) -> list[CalendarPublicationResponse]:
    if not publications:
        return []

    people = await PersonRepository(db).get_options(
        publication.published_by
        for publication in publications
        if publication.published_by is not None
    )

    return [
        _to_response(
            publication,
            people,
            warnings or [],
            has_changes=(publication.date, publication.band) in (changed or set()),
        )
        for publication in publications
    ]


async def _changed_drafts(
    db: DbSession,
    publications: Sequence[CalendarPublication],
) -> set[tuple[date, str]]:
    service = _service(db)
    changed: set[tuple[date, str]] = set()

    for publication in publications:
        if await service.has_changes(publication):
            changed.add((publication.date, publication.band))

    return changed


def _service(db: DbSession) -> CalendarPublicationService:
    return CalendarPublicationService(
        CalendarPublicationRepository(db),
        LessonRepository(db),
        TeacherRoomAssignmentRepository(db),
        RoomSupervisionRepository(db),
        RoomRepository(db),
    )


@router.get("/", response_model=list[CalendarPublicationResponse])
async def list_publications(
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[CalendarPublicationResponse]:
    publications = await _service(db).list_for(
        date_from=date_from,
        date_to=date_to,
    )

    return await _to_responses(
        db,
        publications,
        changed=await _changed_drafts(db, publications),
    )


@router.post("/", response_model=CalendarPublicationResponse)
async def publish_band(
    payload: CalendarPublicationCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarPublicationResponse:
    publication, warnings = await _service(db).publish(identity, payload)

    return (await _to_responses(db, [publication], warnings=warnings))[0]


@router.post("/{publication_date}/{band}/draft", response_model=CalendarPublicationResponse)
async def reopen_band(
    publication_date: date,
    band: TimeBandEnum,
    db: DbSession,
) -> CalendarPublicationResponse:
    publication = await _service(db).reopen(publication_date, str(band))

    return (await _to_responses(db, [publication]))[0]


# Leaving the bozza without publishing: the part of the day goes back to what it
# was when it was opened. Answers how many of its hours could not be put back —
# a request cancelled while the bozza was open took its hour with it either way.
@router.post("/{publication_date}/{band}/discard", response_model=CalendarDraftDiscarded)
async def discard_draft(
    publication_date: date,
    band: TimeBandEnum,
    db: DbSession,
) -> CalendarDraftDiscarded:
    lost = await _service(db).discard(publication_date, str(band))
    publication = await _service(db).repository.get(publication_date, str(band))

    return CalendarDraftDiscarded(
        publication=(await _to_responses(db, [publication]))[0],
        lost=lost,
    )


@router.delete("/{publication_date}/{band}/draft", response_model=CalendarDraftClosed)
async def close_draft(
    publication_date: date,
    band: TimeBandEnum,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarDraftClosed:
    publication, warnings, resent = await _service(db).settle(
        identity,
        publication_date,
        str(band),
    )

    return CalendarDraftClosed(
        publication=(await _to_responses(db, [publication], warnings=warnings))[0],
        resent=resent,
    )


@router.delete("/{publication_date}/{band}")
async def unpublish_band(
    publication_date: date,
    band: TimeBandEnum,
    db: DbSession,
) -> dict[str, str]:
    await _service(db).unpublish(publication_date, str(band))

    return {"detail": "Calendario in modifica"}
