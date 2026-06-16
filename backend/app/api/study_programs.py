from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db
from app.models.study_program import StudyProgram
from app.models.teaching_offering import TeachingOffering
from app.schemas.study_program import (
    StudyProgramCreate,
    StudyProgramResponse,
    StudyProgramUpdate,
)

router = APIRouter(prefix="/study-programs", tags=["study-programs"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

async def _check_associations(program_id: int, db: AsyncSession):
    stmt = select(TeachingOffering).where(TeachingOffering.study_program_id == program_id)
    res = await db.execute(stmt)
    if res.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="Operazione vietata: l'indirizzo di studio è associato a una o più offerte didattiche."
        )

@router.get("/", response_model=list[StudyProgramResponse])
async def get_study_programs(db: DbSession):
    result = await db.execute(select(StudyProgram))
    return result.scalars().all()

@router.post("/", response_model=StudyProgramResponse)
async def create_study_program(payload: StudyProgramCreate, db: DbSession):
    stmt = select(StudyProgram).where(StudyProgram.name.ilike(payload.name))
    exists = (await db.execute(stmt)).scalars().first()
    if exists:
        raise HTTPException(status_code=400, detail=f'L\'indirizzo di studio "{payload.name}" esiste già.')

    new_program = StudyProgram(**payload.model_dump())
    db.add(new_program)
    await db.commit()
    return new_program

@router.put("/{program_id}", response_model=StudyProgramResponse)
async def update_study_program(program_id: int, payload: StudyProgramUpdate, db: DbSession):
    await _check_associations(program_id, db)

    program = (await db.execute(select(StudyProgram).where(StudyProgram.id == program_id))).scalars().first()
    if not program:
        raise HTTPException(status_code=404, detail="Indirizzo di studio non trovato.")

    # Se il nome cambia, controlla che non esista già
    if program.name.lower() != payload.name.lower():
        stmt_conflict = select(StudyProgram).where(StudyProgram.name.ilike(payload.name))
        conflict = (await db.execute(stmt_conflict)).scalars().first()
        if conflict:
            raise HTTPException(status_code=400, detail=f'L\'indirizzo di studio "{payload.name}" esiste già.')

    program.name = payload.name
    program.description = payload.description

    await db.commit()
    return program

@router.delete("/{program_id}")
async def delete_study_program(program_id: int, db: DbSession):
    await _check_associations(program_id, db)

    program = (await db.execute(select(StudyProgram).where(StudyProgram.id == program_id))).scalars().first()
    if not program:
        raise HTTPException(status_code=404, detail="Indirizzo di studio non trovato.")
        
    await db.delete(program)
    await db.commit()
    return {"detail": "Indirizzo di studio eliminato."}