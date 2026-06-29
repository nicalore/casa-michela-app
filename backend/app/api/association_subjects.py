from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db
from app.models.association_subject import AssociationSubject
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.teaching_competence import TeachingCompetence
from app.schemas.association_subject import (
    AssociationSubjectCreate,
    AssociationSubjectResponse,
    AssociationSubjectUpdate,
)

router = APIRouter(prefix="/association-subjects", tags=["association-subjects"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

@router.get("/", response_model=list[AssociationSubjectResponse])
async def get_subjects(db: DbSession):
    result = await db.execute(
        select(AssociationSubject).order_by(AssociationSubject.created_at.desc())
    )
    return result.scalars().all()

@router.post("/", response_model=AssociationSubjectResponse)
async def create_subject(payload: AssociationSubjectCreate, db: DbSession):
    stmt = select(AssociationSubject).where(AssociationSubject.name.ilike(payload.name))
    if (await db.execute(stmt)).scalars().first():
        raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.name}"')

    new_subject = AssociationSubject(**payload.model_dump())
    db.add(new_subject)
    await db.commit()
    return new_subject

@router.put("/{subject_id}", response_model=AssociationSubjectResponse)
async def update_subject(subject_id: int, payload: AssociationSubjectUpdate, db: DbSession):
    subject = (await db.execute(select(AssociationSubject).where(AssociationSubject.id == subject_id))).scalars().first()
    if not subject:
        raise HTTPException(status_code=404, detail="Materia non trovata.")

    if subject.name.lower() != payload.name.lower():
        conflict = (await db.execute(select(AssociationSubject).where(AssociationSubject.name.ilike(payload.name)))).scalars().first()
        if conflict:
            raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.name}"')

    subject.name = payload.name
    subject.area = payload.area
    subject.description = payload.description

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Errore durante l'aggiornamento.") from e
    
    return subject

@router.delete("/{subject_id}")
async def delete_subject(subject_id: int, db: DbSession):
    subject = (await db.execute(select(AssociationSubject).where(AssociationSubject.id == subject_id))).scalars().first()
    if not subject:
        raise HTTPException(status_code=404, detail="Materia non trovata.")

    # Controllo materie ministeriali rimaste senza discipline interne
    subq_min = select(MinistryAssociationSubject.ministry_subject_id).where(
        MinistryAssociationSubject.association_subject_id == subject_id
    )
    stmt_min = select(MinistryAssociationSubject.ministry_subject_id).where(
        MinistryAssociationSubject.ministry_subject_id.in_(subq_min)
    ).group_by(MinistryAssociationSubject.ministry_subject_id).having(
        func.count(MinistryAssociationSubject.association_subject_id) == 1
    )
    
    if (await db.execute(stmt_min)).scalars().first():
        raise HTTPException(status_code=400, detail="Impossibile eliminare: una materia ministeriale rimarrebbe senza discipline interne collegate.")

    # Controllo docenti rimasti senza competenze
    subq_teachers = select(TeachingCompetence.teacher_tax_code).where(
        TeachingCompetence.association_subject_id == subject_id
    )
    stmt_teachers = select(TeachingCompetence.teacher_tax_code).where(
        TeachingCompetence.teacher_tax_code.in_(subq_teachers)
    ).group_by(TeachingCompetence.teacher_tax_code).having(
        func.count(TeachingCompetence.association_subject_id) == 1
    )
    
    if (await db.execute(stmt_teachers)).scalars().first():
        raise HTTPException(status_code=400, detail="Impossibile eliminare: un docente rimarrebbe senza competenze.")

    try:
        await db.delete(subject)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare la materia in quanto protetta da vincoli referenziali.") from e
    
    return {"detail": "Materia eliminata"}