from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import DbSession
from app.api.queries import select_parents_left_without_children
from app.models.association_subject import AssociationSubject
from app.models.ministry_subject import MinistrySubject
from app.models.study_program import EducationLevelEnum
from app.models.study_program_subject import StudyProgramSubject
from app.schemas.ministry_subject import (
    MinistrySubjectCreate,
    MinistrySubjectResponse,
    MinistrySubjectUpdate,
)

router = APIRouter(prefix="/ministry-subjects", tags=["ministry-subjects"])

_SUBJECT_NOT_FOUND_ERROR: Final[str] = "Materia non trovata."
_NO_ASSOCIATION_SUBJECTS_ERROR: Final[str] = "Seleziona almeno una disciplina interna."
_MISSING_ASSOCIATION_SUBJECTS_ERROR: Final[str] = (
    "Alcune discipline interne selezionate non esistono."
)
_DUPLICATE_SUBJECT_ERROR: Final[str] = (
    'Esiste già la materia "{name}" per questo livello.'
)
_CREATE_ERROR: Final[str] = "Errore durante la creazione della disciplina."
_UPDATE_ERROR: Final[str] = "Errore durante la modifica."
_ORPHAN_STUDY_PROGRAM_ERROR: Final[str] = (
    "Impossibile eliminare: un percorso di studi rimarrebbe senza materie "
    "ministeriali associate."
)
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare la materia perché associata ad altri dati."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Materia eliminata"


async def _get_subject_or_404(
    db: AsyncSession,
    subject_id: int,
    *,
    load_associations: bool = False,
) -> MinistrySubject:
    stmt = select(MinistrySubject).where(MinistrySubject.id == subject_id)

    if load_associations:
        stmt = stmt.options(selectinload(MinistrySubject.association_subjects))

    subject = (await db.execute(stmt)).scalars().first()

    if subject is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SUBJECT_NOT_FOUND_ERROR,
        )

    return subject


async def _assert_name_available(
    db: AsyncSession,
    name: str,
    level: EducationLevelEnum,
) -> None:
    stmt = select(MinistrySubject).where(
        MinistrySubject.name.ilike(name),
        MinistrySubject.level == level,
    )

    if (await db.execute(stmt)).scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_SUBJECT_ERROR.format(name=name),
        )


async def _load_association_subjects(
    db: AsyncSession,
    association_subject_ids: list[int],
) -> Sequence[AssociationSubject]:
    stmt = select(AssociationSubject).where(
        AssociationSubject.id.in_(association_subject_ids)
    )
    associations = (await db.execute(stmt)).scalars().all()

    if len(associations) != len(association_subject_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MISSING_ASSOCIATION_SUBJECTS_ERROR,
        )

    return associations


@router.get("/", response_model=list[MinistrySubjectResponse])
async def get_ministry_subjects(db: DbSession) -> Sequence[MinistrySubject]:
    stmt = (
        select(MinistrySubject)
        .options(selectinload(MinistrySubject.association_subjects))
        .order_by(MinistrySubject.created_at.desc())
    )
    result = await db.execute(stmt)

    return result.scalars().all()


@router.post("/", response_model=MinistrySubjectResponse)
async def create_ministry_subject(
    payload: MinistrySubjectCreate,
    db: DbSession,
) -> MinistrySubject | None:
    if not payload.association_subject_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_ASSOCIATION_SUBJECTS_ERROR,
        )

    await _assert_name_available(db, payload.name, payload.level)

    associations = await _load_association_subjects(
        db,
        payload.association_subject_ids,
    )

    new_subject = MinistrySubject(
        name=payload.name,
        level=payload.level,
        area=payload.area,
        description=payload.description,
        association_subjects=list(associations),
    )

    db.add(new_subject)

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CREATE_ERROR,
        ) from err

    stmt_reload = (
        select(MinistrySubject)
        .options(selectinload(MinistrySubject.association_subjects))
        .where(MinistrySubject.id == new_subject.id)
    )

    return (await db.execute(stmt_reload)).scalars().first()


@router.put("/{subject_id}", response_model=MinistrySubjectResponse)
async def update_ministry_subject(
    subject_id: int,
    payload: MinistrySubjectUpdate,
    db: DbSession,
) -> MinistrySubject:
    if not payload.association_subject_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_ASSOCIATION_SUBJECTS_ERROR,
        )

    subject = await _get_subject_or_404(db, subject_id, load_associations=True)

    if subject.name.lower() != payload.name.lower() or subject.level != payload.level:
        await _assert_name_available(db, payload.name, payload.level)

    associations = await _load_association_subjects(
        db,
        payload.association_subject_ids,
    )

    subject.name = payload.name
    subject.level = payload.level
    subject.area = payload.area
    subject.description = payload.description
    subject.association_subjects = list(associations)

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UPDATE_ERROR,
        ) from err

    return subject


@router.delete("/{subject_id}")
async def delete_ministry_subject(subject_id: int, db: DbSession) -> dict[str, str]:
    subject = await _get_subject_or_404(db, subject_id)

    orphan_study_programs = await db.execute(
        select_parents_left_without_children(
            StudyProgramSubject.study_program_id,
            StudyProgramSubject.ministry_subject_id,
            subject_id,
        )
    )

    if orphan_study_programs.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_STUDY_PROGRAM_ERROR,
        )

    try:
        await db.delete(subject)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}