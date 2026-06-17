from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.study_program import StudyProgram
from app.models.subject import Subject
from app.models.teaching_offering import EducationLevelEnum, TeachingOffering
from app.models.teaching_offering_subject import TeachingOfferingSubject
from app.models.teaching_offering_year import TeachingOfferingYear
from app.schemas.teaching_offering import (
    OfferingOptions,
    TeachingOfferingCreate,
    TeachingOfferingResponse,
    TeachingOfferingUpdate,
)

router = APIRouter(prefix="/teaching-offerings", tags=["teaching-offerings"])

DbSession = Annotated[AsyncSession, Depends(get_db)]

async def _check_associations(offering_id: int, db: AsyncSession):
    """Blocca la modifica/eliminazione se l'offerta è associata a iscrizioni scolastiche."""
    stmt = select(SchoolEnrollment).where(SchoolEnrollment.teaching_offering_id == offering_id)
    res = await db.execute(stmt)
    if res.scalars().first():
        raise HTTPException(
            status_code=400, 
            detail="Operazione vietata: l'offerta didattica è associata a una o più iscrizioni scolastiche."
        )

@router.get("/options", response_model=OfferingOptions)
async def get_options(db: DbSession):
    schools = (await db.execute(select(School))).scalars().all()
    programs = (await db.execute(select(StudyProgram))).scalars().all()
    subjects = (await db.execute(select(Subject))).scalars().all()

    return {
        "schools": [{"mechanographic_code": s.mechanographic_code, "name": s.name} for s in schools],
        "study_programs": [{"id": p.id, "name": p.name} for p in programs],
        "subjects": [{"id": s.id, "discipline": s.discipline, "specialization": s.specialization} for s in subjects]
    }

def _format_response(offering: TeachingOffering) -> dict:
    return {
        "id": offering.id,
        "school_mechanographic_code": offering.school_mechanographic_code,
        "study_program_id": offering.study_program_id,
        "level": offering.level.value,
        "years": sorted([y.year for y in offering.years]),
        "subject_ids": [s.subject_id for s in offering.teaching_offering_subjects],
        "school_name": offering.school.name,
        "study_program_name": offering.study_program.name,
        "subjects": [
            {"id": s.subject.id, "discipline": s.subject.discipline, "specialization": s.subject.specialization}
            for s in offering.teaching_offering_subjects
        ]
    }

@router.get("/", response_model=list[TeachingOfferingResponse])
async def get_offerings(db: DbSession):
    stmt = select(TeachingOffering).options(
        selectinload(TeachingOffering.school),
        selectinload(TeachingOffering.study_program),
        selectinload(TeachingOffering.years),
        selectinload(TeachingOffering.teaching_offering_subjects).selectinload(TeachingOfferingSubject.subject)
    )
    offerings = (await db.execute(stmt)).scalars().all()
    return [_format_response(o) for o in offerings]

@router.post("/", response_model=TeachingOfferingResponse)
async def create_offering(payload: TeachingOfferingCreate, db: DbSession):
    stmt = select(TeachingOffering).where(
        TeachingOffering.school_mechanographic_code == payload.school_mechanographic_code,
        TeachingOffering.study_program_id == payload.study_program_id,
        TeachingOffering.level == payload.level
    )
    if (await db.execute(stmt)).scalars().first():
        raise HTTPException(status_code=400, detail="Esiste già un'offerta didattica identica.")

    if not payload.subject_ids:
        raise HTTPException(status_code=400, detail="Devi selezionare almeno una materia.")

    offering = TeachingOffering(
        level=EducationLevelEnum(payload.level),
        school_mechanographic_code=payload.school_mechanographic_code,
        study_program_id=payload.study_program_id,
    )
    
    for y in payload.years:
        offering.years.append(TeachingOfferingYear(year=y))
    for s_id in payload.subject_ids:
        offering.teaching_offering_subjects.append(TeachingOfferingSubject(subject_id=s_id))

    db.add(offering)
    await db.commit()
    
    stmt_reload = select(TeachingOffering).options(
        selectinload(TeachingOffering.school),
        selectinload(TeachingOffering.study_program),
        selectinload(TeachingOffering.years),
        selectinload(TeachingOffering.teaching_offering_subjects).selectinload(TeachingOfferingSubject.subject)
    ).where(TeachingOffering.id == offering.id)
    
    loaded_offering = (await db.execute(stmt_reload)).scalars().first()
    if not loaded_offering:
        raise HTTPException(status_code=500, detail="Errore imprevisto durante il caricamento dell'offerta creata.")
        
    return _format_response(loaded_offering)

@router.put("/{offering_id}", response_model=TeachingOfferingResponse)
async def update_offering(offering_id: int, payload: TeachingOfferingUpdate, db: DbSession):
    # Controllo che non ci siano iscritti
    await _check_associations(offering_id, db)

    # Controllo unicità
    stmt = select(TeachingOffering).where(
        TeachingOffering.school_mechanographic_code == payload.school_mechanographic_code,
        TeachingOffering.study_program_id == payload.study_program_id,
        TeachingOffering.level == payload.level,
        TeachingOffering.id != offering_id # Escludo se stessa
    )
    if (await db.execute(stmt)).scalars().first():
        raise HTTPException(status_code=400, detail="Esiste già un'offerta didattica identica.")

    if not payload.subject_ids:
        raise HTTPException(status_code=400, detail="Devi selezionare almeno una materia.")

    offering = (await db.execute(select(TeachingOffering).where(TeachingOffering.id == offering_id))).scalars().first()
    if not offering:
        raise HTTPException(status_code=404, detail="Offerta didattica non trovata.")

    offering.school_mechanographic_code = payload.school_mechanographic_code
    offering.study_program_id = payload.study_program_id
    offering.level = EducationLevelEnum(payload.level)

    # Aggiorniamo le relazioni manualmente e in sicurezza
    await db.execute(delete(TeachingOfferingYear).where(TeachingOfferingYear.offering_id == offering_id))
    for y in payload.years:
        db.add(TeachingOfferingYear(offering_id=offering_id, year=y))

    await db.execute(delete(TeachingOfferingSubject).where(TeachingOfferingSubject.teaching_offering_id == offering_id))
    for s_id in payload.subject_ids:
        db.add(TeachingOfferingSubject(teaching_offering_id=offering_id, subject_id=s_id))

    await db.commit()

    stmt_reload = select(TeachingOffering).options(
        selectinload(TeachingOffering.school),
        selectinload(TeachingOffering.study_program),
        selectinload(TeachingOffering.years),
        selectinload(TeachingOffering.teaching_offering_subjects).selectinload(TeachingOfferingSubject.subject)
    ).where(TeachingOffering.id == offering_id)
    
    loaded_offering = (await db.execute(stmt_reload)).scalars().first()
    if not loaded_offering:
        raise HTTPException(status_code=500, detail="Errore imprevisto durante l'aggiornamento.")
        
    return _format_response(loaded_offering)


@router.delete("/{offering_id}")
async def delete_offering(offering_id: int, db: DbSession):
    # Controllo che non ci siano iscritti
    await _check_associations(offering_id, db)

    stmt = select(TeachingOffering).where(TeachingOffering.id == offering_id)
    offering = (await db.execute(stmt)).scalars().first()
    if not offering:
        raise HTTPException(status_code=404, detail="Offerta didattica non trovata.")
        
    await db.delete(offering)
    await db.commit()
    return {"detail": "Eliminata."}