from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.ministry_subject import MinistrySubject
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.study_program import StudyProgram
from app.models.teaching_competence import TeachingCompetence
from app.schemas.study_program import (
    StudyProgramCreate,
    StudyProgramResponse,
    StudyProgramUpdate,
)

router = APIRouter(prefix="/study-programs", tags=["study-programs"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

@router.get("/", response_model=list[StudyProgramResponse])
async def get_study_programs(db: DbSession):
    stmt = select(StudyProgram).options(
        selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects)
    ).order_by(StudyProgram.created_at.desc())

    result = await db.execute(stmt)
    return result.scalars().unique().all()


@router.post("/", response_model=StudyProgramResponse)
async def create_study_program(payload: StudyProgramCreate, db: DbSession):
    if not payload.ministry_subject_ids:
        raise HTTPException(status_code=400, detail="Seleziona almeno una materia ministeriale.")

    stmt = select(StudyProgram).where(
        StudyProgram.name.ilike(payload.name),
        StudyProgram.level == payload.level
    )
    if (await db.execute(stmt)).scalars().first():
        raise HTTPException(status_code=400, detail="Esiste già un percorso di studio con questo nome e livello.")

    subjects = []
    if payload.ministry_subject_ids:
        stmt_subj = select(MinistrySubject).where(MinistrySubject.id.in_(payload.ministry_subject_ids))
        subjects = (await db.execute(stmt_subj)).scalars().all()
        if len(subjects) != len(payload.ministry_subject_ids):
            raise HTTPException(status_code=400, detail="Alcune materie ministeriali selezionate non esistono.")

        if any(subj.level != payload.level for subj in subjects):
            raise HTTPException(status_code=400, detail="Tutte le materie ministeriali devono avere lo stesso livello del percorso.")

    new_program = StudyProgram(
        name=payload.name,
        description=payload.description,
        level=payload.level,
        min_year=payload.min_year,
        max_year=payload.max_year,
        ministry_subjects=list(subjects)
    )

    db.add(new_program)

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Dati non validi (es. intervallo anni).") from e

    stmt_reload = select(StudyProgram).options(
        selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects)
    ).where(StudyProgram.id == new_program.id)

    return (await db.execute(stmt_reload)).scalars().first()


@router.put("/{program_id}", response_model=StudyProgramResponse)
async def update_study_program(program_id: int, payload: StudyProgramUpdate, db: DbSession):
    if not payload.ministry_subject_ids:
        raise HTTPException(status_code=400, detail="Seleziona almeno una materia ministeriale.")

    program = (await db.execute(
        select(StudyProgram)
        .options(selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects))
        .where(StudyProgram.id == program_id)
    )).scalars().first()

    if not program:
        raise HTTPException(status_code=404, detail="Indirizzo di studio non trovato.")

    if program.name.lower() != payload.name.lower() or program.level != payload.level:
        stmt_conflict = select(StudyProgram).where(
            StudyProgram.name.ilike(payload.name),
            StudyProgram.level == payload.level
        )
        if (await db.execute(stmt_conflict)).scalars().first():
            raise HTTPException(status_code=400, detail="Esiste già un percorso di studio con questo nome e livello.")

    subjects = []
    if payload.ministry_subject_ids:
        stmt_subj = select(MinistrySubject).where(MinistrySubject.id.in_(payload.ministry_subject_ids))
        subjects = (await db.execute(stmt_subj)).scalars().all()
        if len(subjects) != len(payload.ministry_subject_ids):
            raise HTTPException(status_code=400, detail="Alcune materie ministeriali selezionate non esistono.")

        if any(subj.level != payload.level for subj in subjects):
            raise HTTPException(status_code=400, detail="Tutte le materie ministeriali devono avere lo stesso livello del percorso.")

    program.name = payload.name
    program.description = payload.description
    program.level = payload.level
    program.min_year = payload.min_year
    program.max_year = payload.max_year
    program.ministry_subjects = list(subjects)

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Dati non validi o anni non coerenti per il livello selezionato.") from e

    stmt_reload = select(StudyProgram).options(
        selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects)
    ).where(StudyProgram.id == program_id)

    return (await db.execute(stmt_reload)).scalars().first()


@router.delete("/{program_id}")
async def delete_study_program(program_id: int, db: DbSession):
    program = (await db.execute(select(StudyProgram).where(StudyProgram.id == program_id))).scalars().first()
    if not program:
        raise HTTPException(status_code=404, detail="Indirizzo di studio non trovato.")

    # 1. Controllo studenti iscritti
    stmt_students = select(SchoolEnrollment.id).where(SchoolEnrollment.study_program_id == program_id).limit(1)
    if (await db.execute(stmt_students)).scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Impossibile eliminare il percorso di studi: è frequentato (o lo è stato) da uno o più studenti."
        )

    # 2. Controllo scuole rimaste senza percorsi (ora su school_id)
    subq_schools = select(SchoolStudyProgram.school_id).where(
        SchoolStudyProgram.study_program_id == program_id
    )
    stmt_schools = select(SchoolStudyProgram.school_id).where(
        SchoolStudyProgram.school_id.in_(subq_schools)
    ).group_by(SchoolStudyProgram.school_id).having(
        func.count(SchoolStudyProgram.study_program_id) == 1
    )

    if (await db.execute(stmt_schools)).scalars().first():
        raise HTTPException(status_code=400, detail="Impossibile eliminare il percorso di studi: una o più scuole rimarrebbero senza percorsi.")

    # 3. Controllo docenti rimasti senza competenze
    subq_teachers = select(TeachingCompetence.teacher_tax_code).where(
        TeachingCompetence.study_program_id == program_id
    )
    stmt_teachers = select(TeachingCompetence.teacher_tax_code).where(
        TeachingCompetence.teacher_tax_code.in_(subq_teachers)
    ).group_by(TeachingCompetence.teacher_tax_code).having(
        func.count(TeachingCompetence.study_program_id) == 1
    )

    if (await db.execute(stmt_teachers)).scalars().first():
        raise HTTPException(status_code=400, detail="Impossibile eliminare il percorso di studi: uno o più docenti rimarrebbero senza competenze associate.")

    try:
        await db.delete(program)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare il percorso di studi in quanto protetto da vincoli referenziali.") from e

    return {"detail": "Indirizzo di studio eliminato."}