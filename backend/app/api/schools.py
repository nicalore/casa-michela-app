import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.school import School
from app.models.school_study_program import SchoolStudyProgram
from app.schemas.school import SchoolCreate, SchoolResponse, SchoolUpdate

router = APIRouter(prefix="/schools", tags=["schools"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

@router.get("/", response_model=list[SchoolResponse])
async def get_schools(db: DbSession):
    stmt = select(School).options(
        selectinload(School.study_programs)
    ).order_by(School.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().unique().all()

@router.post("/", response_model=SchoolResponse)
async def create_school(payload: SchoolCreate, db: DbSession):
    if payload.is_private:
        code = f"PRIV-{uuid.uuid4().hex[:6].upper()}"
        while (await db.execute(select(School).where(School.mechanographic_code == code))).scalars().first():
            code = f"PRIV-{uuid.uuid4().hex[:6].upper()}"
    else:
        code = payload.mechanographic_code.upper().strip()
        if len(code) != 10:
            raise HTTPException(status_code=400, detail="Il codice meccanografico deve essere di 10 caratteri.")
        if code[:2] != payload.province:
            raise HTTPException(status_code=400, detail="Le prime due lettere del codice devono corrispondere alla provincia.")

    exists = (await db.execute(select(School).where(School.mechanographic_code == code))).scalars().first()
    if exists:
        raise HTTPException(status_code=400, detail=f'Esiste già una scuola con codice "{code}".')

    new_school = School(
        mechanographic_code=code,
        name=payload.name,
        city=payload.city,
        province=payload.province
    )
    
    if hasattr(payload, 'study_program_ids') and payload.study_program_ids:
        new_school.school_study_programs = [
            SchoolStudyProgram(study_program_id=pid) for pid in payload.study_program_ids
        ]

    db.add(new_school)
    await db.commit()
    
    stmt = select(School).options(
        selectinload(School.study_programs)
    ).where(School.mechanographic_code == code)
    return (await db.execute(stmt)).scalars().first()

@router.put("/{old_code}", response_model=SchoolResponse)
async def update_school(old_code: str, payload: SchoolUpdate, db: DbSession):
    stmt = select(School).options(
        selectinload(School.school_study_programs)
    ).where(School.mechanographic_code == old_code)
    
    school = (await db.execute(stmt)).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")

    if payload.is_private:
        code = old_code if old_code.startswith("PRIV-") else f"PRIV-{uuid.uuid4().hex[:6].upper()}"
    else:
        code = payload.mechanographic_code.upper().strip()
        if len(code) != 10:
            raise HTTPException(status_code=400, detail="Il codice meccanografico deve essere di 10 caratteri.")
        if code[:2] != payload.province:
            raise HTTPException(status_code=400, detail="Le prime due lettere del codice devono corrispondere alla provincia.")

    if old_code != code:
        conflict = (await db.execute(select(School).where(School.mechanographic_code == code))).scalars().first()
        if conflict:
            raise HTTPException(status_code=400, detail=f'Esiste già una scuola con codice "{code}".')

    school.mechanographic_code = code
    school.name = payload.name
    school.city = payload.city
    school.province = payload.province

    school.school_study_programs.clear()
    if hasattr(payload, 'study_program_ids') and payload.study_program_ids:
        school.school_study_programs.extend([
            SchoolStudyProgram(study_program_id=pid) for pid in payload.study_program_ids
        ])

    try:
        await db.commit()
        stmt_refresh = select(School).options(
            selectinload(School.study_programs)
        ).where(School.mechanographic_code == code)
        return (await db.execute(stmt_refresh)).scalars().first()

    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Errore di integrità durante l'aggiornamento.") from e
    
@router.delete("/{code}")
async def delete_school(code: str, db: DbSession):
    school = (await db.execute(select(School).where(School.mechanographic_code == code))).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")
        
    try:
        await db.delete(school)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Impossibile eliminare la scuola perché collegata ad altri dati protetti.") from e
    
    return {"detail": "Scuola eliminata"}