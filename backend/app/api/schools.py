import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db
from app.models.school import School
from app.models.teaching_offering import TeachingOffering
from app.schemas.school import SchoolCreate, SchoolResponse, SchoolUpdate

router = APIRouter(prefix="/schools", tags=["schools"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

async def _check_associations(code: str, db: AsyncSession):
    stmt = select(TeachingOffering).where(TeachingOffering.school.has(mechanographic_code=code))
    res = await db.execute(stmt)
    if res.scalars().first():
        raise HTTPException(status_code=400, detail="Operazione vietata: la scuola è presente in una o più offerte didattiche.")

@router.get("/", response_model=list[SchoolResponse])
async def get_schools(db: DbSession):
    result = await db.execute(select(School))
    return result.scalars().all()

@router.post("/", response_model=SchoolResponse)
async def create_school(payload: SchoolCreate, db: DbSession):
    if payload.is_private:
        # Genera codice univoco: es. PRIV-4F8A2B
        code = f"PRIV-{uuid.uuid4().hex[:6].upper()}"
        # Assicura unicità assoluta
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
    db.add(new_school)
    await db.commit()
    return new_school

@router.put("/{old_code}", response_model=SchoolResponse)
async def update_school(old_code: str, payload: SchoolUpdate, db: DbSession):
    await _check_associations(old_code, db)

    if payload.is_private:
        # Se era già privata, mantieni il codice vecchio per non romperlo. Altrimenti generane uno nuovo.
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

    school = (await db.execute(select(School).where(School.mechanographic_code == old_code))).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")

    school.mechanographic_code = code
    school.name = payload.name
    school.city = payload.city
    school.province = payload.province

    await db.commit()
    return school

@router.delete("/{code}")
async def delete_school(code: str, db: DbSession):
    await _check_associations(code, db)
    school = (await db.execute(select(School).where(School.mechanographic_code == code))).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")
        
    await db.delete(school)
    await db.commit()
    return {"detail": "Scuola eliminata"}
