from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.queries import select_parents_left_without_children
from app.models.association_subject import AssociationSubject
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.teaching_competence import TeachingCompetence
from app.schemas.association_subject import (
    AssociationSubjectCreate,
    AssociationSubjectResponse,
    AssociationSubjectUpdate,
)

router = APIRouter(prefix="/association-subjects", tags=["association-subjects"])

_SUBJECT_NOT_FOUND_ERROR: Final[str] = "Materia non trovata."
_DUPLICATE_SUBJECT_ERROR: Final[str] = 'Esiste già la disciplina "{name}"'
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."
_ORPHAN_MINISTRY_SUBJECT_ERROR: Final[str] = (
    "Impossibile eliminare: una materia ministeriale rimarrebbe senza "
    "discipline interne collegate."
)
_ORPHAN_TEACHER_ERROR: Final[str] = (
    "Impossibile eliminare: un docente rimarrebbe senza competenze."
)
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare la materia in quanto protetta da vincoli referenziali."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Materia eliminata"


async def _get_subject_or_404(db: AsyncSession, subject_id: int) -> AssociationSubject:
    result = await db.execute(
        select(AssociationSubject).where(AssociationSubject.id == subject_id)
    )
    subject = result.scalars().first()

    if subject is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SUBJECT_NOT_FOUND_ERROR,
        )

    return subject


async def _assert_name_available(db: AsyncSession, name: str) -> None:
    result = await db.execute(
        select(AssociationSubject).where(AssociationSubject.name.ilike(name))
    )

    if result.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_SUBJECT_ERROR.format(name=name),
        )


@router.get("/", response_model=list[AssociationSubjectResponse])
async def get_subjects(db: DbSession) -> Sequence[AssociationSubject]:
    result = await db.execute(
        select(AssociationSubject).order_by(AssociationSubject.created_at.desc())
    )

    return result.scalars().all()


@router.post("/", response_model=AssociationSubjectResponse)
async def create_subject(
    payload: AssociationSubjectCreate,
    db: DbSession,
) -> AssociationSubject:
    await _assert_name_available(db, payload.name)

    new_subject = AssociationSubject(**payload.model_dump())
    db.add(new_subject)
    await db.commit()

    return new_subject


@router.put("/{subject_id}", response_model=AssociationSubjectResponse)
async def update_subject(
    subject_id: int,
    payload: AssociationSubjectUpdate,
    db: DbSession,
) -> AssociationSubject:
    subject = await _get_subject_or_404(db, subject_id)

    if subject.name.lower() != payload.name.lower():
        await _assert_name_available(db, payload.name)

    subject.name = payload.name
    subject.area = payload.area
    subject.description = payload.description

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
async def delete_subject(subject_id: int, db: DbSession) -> dict[str, str]:
    subject = await _get_subject_or_404(db, subject_id)

    orphan_ministry_subjects = await db.execute(
        select_parents_left_without_children(
            MinistryAssociationSubject.ministry_subject_id,
            MinistryAssociationSubject.association_subject_id,
            subject_id,
        )
    )

    if orphan_ministry_subjects.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_MINISTRY_SUBJECT_ERROR,
        )

    orphan_teachers = await db.execute(
        select_parents_left_without_children(
            TeachingCompetence.teacher_tax_code,
            TeachingCompetence.association_subject_id,
            subject_id,
        )
    )

    if orphan_teachers.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_TEACHER_ERROR,
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