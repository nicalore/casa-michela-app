from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db
from app.models.association_subject import AssociationSubject
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
        
    try:
        await db.delete(subject)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare la materia.") from e
    
    return {"detail": "Materia eliminata"}