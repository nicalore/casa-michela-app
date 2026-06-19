from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.ministry_subject import MinistrySubject
from app.models.study_program import StudyProgram
from app.schemas.study_program import (
    StudyProgramCreate,
    StudyProgramResponse,
    StudyProgramUpdate,
)

router = APIRouter(prefix="/study-programs", tags=["study-programs"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

@router.get("/", response_model=list[StudyProgramResponse])
async def get_study_programs(db: DbSession):
    # Caricamento a cascata profondo: StudyProgram -> MinistrySubject -> AssociationSubject
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
        
        # Controllo di coerenza del livello
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
    
    # Ricarica l'oggetto appena creato caricando l'intera profondità relazionale
    stmt_reload = select(StudyProgram).options(
        selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects)
    ).where(StudyProgram.id == new_program.id)
    
    return (await db.execute(stmt_reload)).scalars().first()


@router.put("/{program_id}", response_model=StudyProgramResponse)
async def update_study_program(program_id: int, payload: StudyProgramUpdate, db: DbSession):
    if not payload.ministry_subject_ids:
        raise HTTPException(status_code=400, detail="Seleziona almeno una materia ministeriale.")

    # Carica il programma e le sue relazioni a cascata
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

        # Controllo di coerenza del livello
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
    
    # Ricarica per restituire lo stato finale coerente e serializzabile (con association_subjects espliciti in memoria)
    stmt_reload = select(StudyProgram).options(
        selectinload(StudyProgram.ministry_subjects).selectinload(MinistrySubject.association_subjects)
    ).where(StudyProgram.id == program_id)
    
    return (await db.execute(stmt_reload)).scalars().first()


@router.delete("/{program_id}")
async def delete_study_program(program_id: int, db: DbSession):
    program = (await db.execute(select(StudyProgram).where(StudyProgram.id == program_id))).scalars().first()
    if not program:
        raise HTTPException(status_code=404, detail="Indirizzo di studio non trovato.")
        
    try:
        await db.delete(program)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare il percorso di studi.") from e
    
    return {"detail": "Indirizzo di studio eliminato."}