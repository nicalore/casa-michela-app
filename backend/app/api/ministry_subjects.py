from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.association_subject import AssociationSubject
from app.models.ministry_subject import MinistrySubject
from app.models.study_program_subject import StudyProgramSubject
from app.schemas.ministry_subject import (
    MinistrySubjectCreate,
    MinistrySubjectResponse,
    MinistrySubjectUpdate,
)

router = APIRouter(prefix="/ministry-subjects", tags=["ministry-subjects"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

@router.get("/", response_model=list[MinistrySubjectResponse])
async def get_ministry_subjects(db: DbSession):
    stmt = select(MinistrySubject).options(
        selectinload(MinistrySubject.association_subjects)
    ).order_by(MinistrySubject.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/", response_model=MinistrySubjectResponse)
async def create_ministry_subject(payload: MinistrySubjectCreate, db: DbSession):
    if not payload.association_subject_ids:
        raise HTTPException(status_code=400, detail="Seleziona almeno una disciplina interna.")

    stmt = select(MinistrySubject).where(
        MinistrySubject.name.ilike(payload.name), 
        MinistrySubject.level == payload.level
    )
    if (await db.execute(stmt)).scalars().first():
        raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.name}" per questo livello.')

    associations = []
    if payload.association_subject_ids:
        stmt_assoc = select(AssociationSubject).where(AssociationSubject.id.in_(payload.association_subject_ids))
        associations = (await db.execute(stmt_assoc)).scalars().all()
        if len(associations) != len(payload.association_subject_ids):
            raise HTTPException(status_code=400, detail="Alcune discipline interne selezionate non esistono.")

    new_subject = MinistrySubject(
        name=payload.name,
        level=payload.level,
        area=payload.area,
        description=payload.description,
        association_subjects=list(associations)
    )
    
    db.add(new_subject)
    
    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Errore durante la creazione.") from e

    stmt_reload = select(MinistrySubject).options(
        selectinload(MinistrySubject.association_subjects)
    ).where(MinistrySubject.id == new_subject.id)
    
    return (await db.execute(stmt_reload)).scalars().first()


@router.put("/{subject_id}", response_model=MinistrySubjectResponse)
async def update_ministry_subject(subject_id: int, payload: MinistrySubjectUpdate, db: DbSession):
    if not payload.association_subject_ids:
        raise HTTPException(status_code=400, detail="Seleziona almeno una disciplina interna.")

    subject = (await db.execute(
        select(MinistrySubject)
        .options(selectinload(MinistrySubject.association_subjects))
        .where(MinistrySubject.id == subject_id)
    )).scalars().first()
    
    if not subject:
        raise HTTPException(status_code=404, detail="Materia non trovata.")

    if subject.name.lower() != payload.name.lower() or subject.level != payload.level:
        conflict_stmt = select(MinistrySubject).where(
            MinistrySubject.name.ilike(payload.name), 
            MinistrySubject.level == payload.level
        )
        if (await db.execute(conflict_stmt)).scalars().first():
            raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.name}" per questo livello.')

    associations = []
    if payload.association_subject_ids:
        stmt_assoc = select(AssociationSubject).where(AssociationSubject.id.in_(payload.association_subject_ids))
        associations = (await db.execute(stmt_assoc)).scalars().all()
        if len(associations) != len(payload.association_subject_ids):
            raise HTTPException(status_code=400, detail="Alcune discipline interne selezionate non esistono.")

    subject.name = payload.name
    subject.level = payload.level
    subject.area = payload.area
    subject.description = payload.description
    subject.association_subjects = list(associations)

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Errore durante la modifica.") from e

    return subject


@router.delete("/{subject_id}")
async def delete_ministry_subject(subject_id: int, db: DbSession):
    subject = (await db.execute(select(MinistrySubject).where(MinistrySubject.id == subject_id))).scalars().first()
    if not subject:
        raise HTTPException(status_code=404, detail="Materia non trovata.")

    # Controllo percorsi di studi rimasti senza materie ministeriali
    subq_prog = select(StudyProgramSubject.study_program_id).where(
        StudyProgramSubject.ministry_subject_id == subject_id
    )
    stmt_prog = select(StudyProgramSubject.study_program_id).where(
        StudyProgramSubject.study_program_id.in_(subq_prog)
    ).group_by(StudyProgramSubject.study_program_id).having(
        func.count(StudyProgramSubject.ministry_subject_id) == 1
    )
    
    if (await db.execute(stmt_prog)).scalars().first():
        raise HTTPException(status_code=400, detail="Impossibile eliminare: un percorso di studi rimarrebbe senza materie ministeriali associate.")
        
    try:
        await db.delete(subject)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare la materia perché associata ad altri dati.") from e
        
    return {"detail": "Materia eliminata"}