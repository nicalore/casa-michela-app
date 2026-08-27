from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.sql.base import ExecutableOption

from app.api.dependencies import DbSession
from app.api.queries import select_parents_left_without_children
from app.models.ministry_subject import MinistrySubject
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.study_program import EducationLevelEnum, StudyProgram
from app.models.teaching_competence import TeachingCompetence
from app.schemas.study_program import (
    StudyProgramCreate,
    StudyProgramResponse,
    StudyProgramUpdate,
)

router = APIRouter(prefix="/study-programs", tags=["study-programs"])

_PROGRAM_NOT_FOUND_ERROR: Final[str] = "Indirizzo di studio non trovato."
_NO_MINISTRY_SUBJECTS_ERROR: Final[str] = "Seleziona almeno una materia ministeriale."
_MISSING_MINISTRY_SUBJECTS_ERROR: Final[str] = (
    "Alcune materie ministeriali selezionate non esistono."
)
_LEVEL_MISMATCH_ERROR: Final[str] = (
    "Tutte le materie ministeriali devono avere lo stesso livello del percorso."
)
_DUPLICATE_PROGRAM_ERROR: Final[str] = (
    "Esiste già un percorso di studio con questo nome e livello."
)
_CREATE_ERROR: Final[str] = "Dati non validi (es. intervallo anni)."
_UPDATE_ERROR: Final[str] = (
    "Dati non validi o anni non coerenti per il livello selezionato."
)
_ATTENDED_PROGRAM_ERROR: Final[str] = (
    "Impossibile eliminare il percorso di studi: è frequentato (o lo è stato) "
    "da uno o più studenti."
)
_ORPHAN_SCHOOL_ERROR: Final[str] = (
    "Impossibile eliminare il percorso di studi: una o più scuole rimarrebbero "
    "senza percorsi."
)
_ORPHAN_TEACHER_ERROR: Final[str] = (
    "Impossibile eliminare il percorso di studi: uno o più docenti rimarrebbero "
    "senza competenze associate."
)
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare il percorso di studi in quanto protetto da vincoli "
    "referenziali."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Indirizzo di studio eliminato."


def _subjects_load_option() -> ExecutableOption:
    return selectinload(StudyProgram.ministry_subjects).selectinload(
        MinistrySubject.association_subjects
    )


async def _load_program_with_subjects(
    db: AsyncSession,
    program_id: int,
) -> StudyProgram | None:
    stmt = (
        select(StudyProgram)
        .options(_subjects_load_option())
        .where(StudyProgram.id == program_id)
    )

    return (await db.execute(stmt)).scalars().first()


async def _get_program_or_404(
    db: AsyncSession,
    program_id: int,
    *,
    load_subjects: bool = False,
) -> StudyProgram:
    stmt = select(StudyProgram).where(StudyProgram.id == program_id)

    if load_subjects:
        stmt = stmt.options(_subjects_load_option())

    program = (await db.execute(stmt)).scalars().first()

    if program is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PROGRAM_NOT_FOUND_ERROR,
        )

    return program


async def _assert_name_available(
    db: AsyncSession,
    name: str,
    level: EducationLevelEnum,
    sector: str | None,
) -> None:
    # The sector is part of the programme's identity.
    stmt = select(StudyProgram).where(
        StudyProgram.name.ilike(name),
        StudyProgram.level == level,
        func.coalesce(StudyProgram.sector, "") == (sector or ""),
    )

    if (await db.execute(stmt)).scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_PROGRAM_ERROR,
        )


async def _load_ministry_subjects(
    db: AsyncSession,
    ministry_subject_ids: list[int],
    level: EducationLevelEnum,
) -> Sequence[MinistrySubject]:
    stmt = select(MinistrySubject).where(
        MinistrySubject.id.in_(ministry_subject_ids)
    )
    subjects = (await db.execute(stmt)).scalars().all()

    if len(subjects) != len(ministry_subject_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MISSING_MINISTRY_SUBJECTS_ERROR,
        )

    if any(subject.level != level for subject in subjects):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_LEVEL_MISMATCH_ERROR,
        )

    return subjects


@router.get("/", response_model=list[StudyProgramResponse])
async def get_study_programs(db: DbSession) -> Sequence[StudyProgram]:
    stmt = (
        select(StudyProgram)
        .options(_subjects_load_option())
        .order_by(StudyProgram.created_at.desc())
    )
    result = await db.execute(stmt)

    return result.scalars().unique().all()


@router.post("/", response_model=StudyProgramResponse)
async def create_study_program(
    payload: StudyProgramCreate,
    db: DbSession,
) -> StudyProgram | None:
    if not payload.ministry_subject_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_MINISTRY_SUBJECTS_ERROR,
        )

    await _assert_name_available(db, payload.name, payload.level, payload.sector)

    subjects = await _load_ministry_subjects(
        db,
        payload.ministry_subject_ids,
        payload.level,
    )

    new_program = StudyProgram(
        name=payload.name,
        sector=payload.sector,
        description=payload.description,
        level=payload.level,
        min_year=payload.min_year,
        max_year=payload.max_year,
        ministry_subjects=list(subjects),
    )

    db.add(new_program)

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CREATE_ERROR,
        ) from err

    return await _load_program_with_subjects(db, new_program.id)


@router.put("/{program_id}", response_model=StudyProgramResponse)
async def update_study_program(
    program_id: int,
    payload: StudyProgramUpdate,
    db: DbSession,
) -> StudyProgram | None:
    if not payload.ministry_subject_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_MINISTRY_SUBJECTS_ERROR,
        )

    program = await _get_program_or_404(db, program_id, load_subjects=True)

    if (
        program.name.lower() != payload.name.lower()
        or program.level != payload.level
        or (program.sector or "") != (payload.sector or "")
    ):
        await _assert_name_available(db, payload.name, payload.level, payload.sector)

    subjects = await _load_ministry_subjects(
        db,
        payload.ministry_subject_ids,
        payload.level,
    )

    program.name = payload.name
    program.sector = payload.sector
    program.description = payload.description
    program.level = payload.level
    program.min_year = payload.min_year
    program.max_year = payload.max_year
    program.ministry_subjects = list(subjects)

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UPDATE_ERROR,
        ) from err

    return await _load_program_with_subjects(db, program_id)


@router.delete("/{program_id}")
async def delete_study_program(program_id: int, db: DbSession) -> dict[str, str]:
    program = await _get_program_or_404(db, program_id)

    enrolled_students = await db.execute(
        select(SchoolEnrollment.id)
        .where(SchoolEnrollment.study_program_id == program_id)
        .limit(1)
    )

    if enrolled_students.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ATTENDED_PROGRAM_ERROR,
        )

    orphan_schools = await db.execute(
        select_parents_left_without_children(
            SchoolStudyProgram.school_id,
            SchoolStudyProgram.study_program_id,
            program_id,
        )
    )

    if orphan_schools.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_SCHOOL_ERROR,
        )

    orphan_teachers = await db.execute(
        select_parents_left_without_children(
            TeachingCompetence.teacher_tax_code,
            TeachingCompetence.study_program_id,
            program_id,
        )
    )

    if orphan_teachers.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_TEACHER_ERROR,
        )

    try:
        await db.delete(program)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}