from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.schemas.school import SchoolCreate, SchoolResponse, SchoolUpdate

router = APIRouter(prefix="/schools", tags=["schools"])

DbSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("/", response_model=list[SchoolResponse])
async def get_schools(db: DbSession):
    stmt = (
        select(School)
        .options(selectinload(School.study_programs))
        .order_by(School.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().unique().all()


@router.post("/", response_model=SchoolResponse)
async def create_school(payload: SchoolCreate, db: DbSession):
    # Controllo proattivo per un messaggio pulito; l'UNIQUE(name, city) resta la
    # garanzia in caso di race condition (gestita più sotto con IntegrityError).
    conflict = (
        await db.execute(
            select(School).where(
                School.name == payload.name,
                School.city == payload.city,
            )
        )
    ).scalars().first()
    if conflict:
        raise HTTPException(
            status_code=409,
            detail=f'Esiste già una scuola "{payload.name}" a {payload.city}.',
        )

    new_school = School(
        mechanographic_code=payload.mechanographic_code,
        name=payload.name,
        city=payload.city,
        province=payload.province,
    )

    if payload.study_program_ids:
        new_school.school_study_programs = [
            SchoolStudyProgram(study_program_id=pid)
            for pid in payload.study_program_ids
        ]

    db.add(new_school)

    try:
        # flush per ottenere l'id generato dal DB prima del commit
        # (dopo il commit l'attributo verrebbe expired e in async non è ricaricabile).
        await db.flush()
        school_id = new_school.id
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Errore di integrità durante la creazione della scuola.",
        ) from e

    stmt = (
        select(School)
        .options(selectinload(School.study_programs))
        .where(School.id == school_id)
    )
    return (await db.execute(stmt)).scalars().first()


@router.put("/{school_id}", response_model=SchoolResponse)
async def update_school(school_id: int, payload: SchoolUpdate, db: DbSession):
    stmt = (
        select(School)
        .options(selectinload(School.school_study_programs))
        .where(School.id == school_id)
    )
    school = (await db.execute(stmt)).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")

    conflict = (
        await db.execute(
            select(School).where(
                School.name == payload.name,
                School.city == payload.city,
                School.id != school_id,
            )
        )
    ).scalars().first()
    if conflict:
        raise HTTPException(
            status_code=409,
            detail=f'Esiste già una scuola "{payload.name}" a {payload.city}.',
        )

    school.mechanographic_code = payload.mechanographic_code
    school.name = payload.name
    school.city = payload.city
    school.province = payload.province

    # Sincronizzazione controllata delle FK senza eliminare quelle frequentate
    current_pids = {ssp.study_program_id for ssp in school.school_study_programs}
    new_pids = set(payload.study_program_ids)

    to_remove = current_pids - new_pids
    to_add = new_pids - current_pids

    if to_remove:
        stmt_check = select(SchoolEnrollment).where(
            SchoolEnrollment.school_id == school_id,
            SchoolEnrollment.study_program_id.in_(to_remove),
        )
        if (await db.execute(stmt_check)).scalars().first():
            raise HTTPException(
                status_code=400,
                detail="Impossibile rimuovere percorsi di studio attualmente o precedentemente frequentati da studenti.",
            )

        school.school_study_programs = [
            ssp
            for ssp in school.school_study_programs
            if ssp.study_program_id not in to_remove
        ]

    for pid in to_add:
        school.school_study_programs.append(SchoolStudyProgram(study_program_id=pid))

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Errore di integrità durante l'aggiornamento della scuola.",
        ) from e

    stmt_refresh = (
        select(School)
        .options(selectinload(School.study_programs))
        .where(School.id == school_id)
    )
    return (await db.execute(stmt_refresh)).scalars().first()


@router.delete("/{school_id}")
async def delete_school(school_id: int, db: DbSession):
    school = (
        await db.execute(select(School).where(School.id == school_id))
    ).scalars().first()
    if not school:
        raise HTTPException(status_code=404, detail="Scuola non trovata.")

    try:
        await db.delete(school)
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Impossibile eliminare la scuola perché ci sono studenti iscritti.",
        ) from e

    return {"detail": "Scuola eliminata"}