from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import DbSession
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.schemas.school import SchoolCreate, SchoolResponse, SchoolUpdate

router = APIRouter(prefix="/schools", tags=["schools"])

_SCHOOL_NOT_FOUND_ERROR: Final[str] = "Scuola non trovata."
_DUPLICATE_SCHOOL_ERROR: Final[str] = 'Esiste già una scuola "{name}" a {city}.'
_CREATE_INTEGRITY_ERROR: Final[str] = (
    "Errore di integrità durante la creazione della scuola."
)
_UPDATE_INTEGRITY_ERROR: Final[str] = (
    "Errore di integrità durante l'aggiornamento della scuola."
)
_ATTENDED_PROGRAM_ERROR: Final[str] = (
    "Impossibile rimuovere percorsi di studio attualmente o precedentemente "
    "frequentati da studenti."
)
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare la scuola perché ci sono studenti iscritti."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Scuola eliminata"


async def _load_school_with_programs(
    db: AsyncSession,
    school_id: int,
) -> School | None:
    stmt = (
        select(School)
        .options(selectinload(School.study_programs))
        .where(School.id == school_id)
    )

    return (await db.execute(stmt)).scalars().first()


async def _get_school_or_404(
    db: AsyncSession,
    school_id: int,
    *,
    load_study_programs: bool = False,
) -> School:
    stmt = select(School).where(School.id == school_id)

    if load_study_programs:
        stmt = stmt.options(selectinload(School.school_study_programs))

    school = (await db.execute(stmt)).scalars().first()

    if school is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SCHOOL_NOT_FOUND_ERROR,
        )

    return school


async def _assert_name_available(
    db: AsyncSession,
    name: str,
    city: str,
    *,
    exclude_id: int | None = None,
) -> None:
    # Checked up front only to return a readable message: UNIQUE(name, city)
    # stays the actual guarantee against a concurrent insert, and is handled
    # by the IntegrityError branch of each endpoint.
    stmt = select(School).where(School.name == name, School.city == city)

    if exclude_id is not None:
        stmt = stmt.where(School.id != exclude_id)

    if (await db.execute(stmt)).scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_DUPLICATE_SCHOOL_ERROR.format(name=name, city=city),
        )


async def _assert_programs_not_attended(
    db: AsyncSession,
    school_id: int,
    study_program_ids: set[int],
) -> None:
    stmt = select(SchoolEnrollment).where(
        SchoolEnrollment.school_id == school_id,
        SchoolEnrollment.study_program_id.in_(study_program_ids),
    )

    if (await db.execute(stmt)).scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ATTENDED_PROGRAM_ERROR,
        )


@router.get("/", response_model=list[SchoolResponse])
async def get_schools(db: DbSession) -> Sequence[School]:
    stmt = (
        select(School)
        .options(selectinload(School.study_programs))
        .order_by(School.created_at.desc())
    )
    result = await db.execute(stmt)

    return result.scalars().unique().all()


@router.post("/", response_model=SchoolResponse)
async def create_school(payload: SchoolCreate, db: DbSession) -> School | None:
    await _assert_name_available(db, payload.name, payload.city)

    new_school = School(
        mechanographic_code=payload.mechanographic_code,
        name=payload.name,
        city=payload.city,
        province=payload.province,
    )

    if payload.study_program_ids:
        new_school.school_study_programs = [
            SchoolStudyProgram(study_program_id=study_program_id)
            for study_program_id in payload.study_program_ids
        ]

    db.add(new_school)

    try:
        await db.flush()
        school_id = new_school.id
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_CREATE_INTEGRITY_ERROR,
        ) from err

    return await _load_school_with_programs(db, school_id)


@router.put("/{school_id}", response_model=SchoolResponse)
async def update_school(
    school_id: int,
    payload: SchoolUpdate,
    db: DbSession,
) -> School | None:
    school = await _get_school_or_404(db, school_id, load_study_programs=True)

    await _assert_name_available(
        db,
        payload.name,
        payload.city,
        exclude_id=school_id,
    )

    school.mechanographic_code = payload.mechanographic_code
    school.name = payload.name
    school.city = payload.city
    school.province = payload.province

    current_ids = {
        link.study_program_id for link in school.school_study_programs
    }
    requested_ids = set(payload.study_program_ids)

    to_remove = current_ids - requested_ids
    to_add = requested_ids - current_ids

    # A study program can only be detached from the school if no enrollment,
    # current or past, ever referenced it.
    if to_remove:
        await _assert_programs_not_attended(db, school_id, to_remove)

        school.school_study_programs = [
            link
            for link in school.school_study_programs
            if link.study_program_id not in to_remove
        ]

    for study_program_id in to_add:
        school.school_study_programs.append(
            SchoolStudyProgram(study_program_id=study_program_id)
        )

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_UPDATE_INTEGRITY_ERROR,
        ) from err

    return await _load_school_with_programs(db, school_id)


@router.delete("/{school_id}")
async def delete_school(school_id: int, db: DbSession) -> dict[str, str]:
    school = await _get_school_or_404(db, school_id)

    try:
        await db.delete(school)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}