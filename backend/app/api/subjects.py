from typing import Annotated

from backend.app.models.association_subject import Subject
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db
from app.models.teacher_subject import TeacherSubject
from app.models.teaching_offering_subject import TeachingOfferingSubject
from app.schemas.subject import SubjectCreate, SubjectGrouped, SubjectUpdate

router = APIRouter(prefix="/subjects", tags=["subjects"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

# --- FUNZIONE DI VALIDAZIONE ---
async def _check_associations(discipline: str, db: AsyncSession):
    """
    Verifica se la disciplina è associata a docenti o offerte didattiche.
    Solleva un'eccezione HTTP 400 se trova delle associazioni.
    """
    # 1. Controllo associazione con i Docenti
    stmt_teachers = select(TeacherSubject).join(TeacherSubject.subject).where(Subject.discipline == discipline)
    res_teachers = await db.execute(stmt_teachers)
    if res_teachers.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="Operazione vietata: la materia è associata a uno o più docenti."
        )
        
    # 2. Controllo associazione con le Offerte Didattiche
    stmt_offerings = select(TeachingOfferingSubject).join(TeachingOfferingSubject.subject).where(Subject.discipline == discipline)
    res_offerings = await db.execute(stmt_offerings)
    if res_offerings.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="Operazione vietata: la materia è presente in una o più offerte didattiche."
        )

# --- ROTTE API ---

@router.get("/", response_model=list[SubjectGrouped])
async def get_subjects(db: DbSession):
    result = await db.execute(select(Subject))
    subjects = result.scalars().all()
    
    grouped = {}
    for s in subjects:
        if s.discipline not in grouped:
            grouped[s.discipline] = []
        if s.specialization:
            grouped[s.discipline].append(s.specialization)

    return [{"discipline": k, "areas": sorted(v)} for k, v in grouped.items()]

@router.post("/", response_model=SubjectGrouped)
async def create_subject(payload: SubjectCreate, db: DbSession):
    stmt = select(Subject).where(Subject.discipline.ilike(payload.discipline))
    result = await db.execute(stmt)
    exists = result.scalars().first()
    
    if exists:
        raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.discipline}"')

    if not payload.areas:
        db.add(Subject(discipline=payload.discipline, specialization=None))
    else:
        for area in payload.areas:
            db.add(Subject(discipline=payload.discipline, specialization=area))
            
    await db.commit()
    return {"discipline": payload.discipline, "areas": payload.areas}

@router.put("/{old_discipline}", response_model=SubjectGrouped)
async def update_subject(old_discipline: str, payload: SubjectUpdate, db: DbSession):
    # BLOCCO DI SICUREZZA: Impedisce la modifica se ci sono associazioni attive
    await _check_associations(old_discipline, db)

    if old_discipline.lower() != payload.discipline.lower():
        stmt_conflict = select(Subject).where(Subject.discipline.ilike(payload.discipline))
        result_conflict = await db.execute(stmt_conflict)
        conflict = result_conflict.scalars().first()
        if conflict:
            raise HTTPException(status_code=400, detail=f'Esiste già la materia "{payload.discipline}"')

    stmt_rows = select(Subject).where(Subject.discipline == old_discipline)
    result_rows = await db.execute(stmt_rows)
    rows = result_rows.scalars().all()
    
    if not rows:
        raise HTTPException(status_code=404, detail="Materia non trovata.")

    new_areas = set(payload.areas)
    existing_areas = {r.specialization: r for r in rows if r.specialization}

    for r in rows:
        r.discipline = payload.discipline

    for spec, r in existing_areas.items():
        if spec not in new_areas:
            await db.delete(r)

    for spec in new_areas:
        if spec not in existing_areas:
            db.add(Subject(discipline=payload.discipline, specialization=spec))

    has_none = any(r.specialization is None for r in rows)
    if new_areas and has_none:
        for r in rows:
            if r.specialization is None:
                await db.delete(r)
    elif not new_areas and not has_none:
        db.add(Subject(discipline=payload.discipline, specialization=None))

    await db.commit()
    return {"discipline": payload.discipline, "areas": payload.areas}

@router.delete("/{discipline}")
async def delete_subject(discipline: str, db: DbSession):
    # BLOCCO DI SICUREZZA: Impedisce l'eliminazione se ci sono associazioni attive
    await _check_associations(discipline, db)

    stmt = select(Subject).where(Subject.discipline == discipline)
    result = await db.execute(stmt)
    rows = result.scalars().all()
    
    if not rows:
        raise HTTPException(status_code=404, detail="Materia non trovata.")
        
    for r in rows:
        await db.delete(r)
        
    await db.commit()
    return {"detail": "Materia eliminata"}