from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.models.course import Course
from app.schemas.course import CourseCreate, CourseResponse, CourseUpdate

router = APIRouter(prefix="/courses", tags=["courses"])

_COURSE_NOT_FOUND_ERROR: Final[str] = "Corso non trovato."
_DUPLICATE_COURSE_ERROR: Final[str] = 'Esiste già il corso "{name}"'
_CREATE_ERROR: Final[str] = "Errore durante la creazione del corso."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare il corso in quanto protetto da vincoli referenziali."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Corso eliminato"


async def _get_course_or_404(db: AsyncSession, name: str) -> Course:
    course = (
        await db.execute(select(Course).where(Course.name == name))
    ).scalars().first()

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_COURSE_NOT_FOUND_ERROR,
        )

    return course


async def _assert_name_available(db: AsyncSession, name: str) -> None:
    # Case-insensitive like the other catalogues; the PK alone would let
    # "Yoga" and "yoga" both through.
    existing = (
        await db.execute(select(Course).where(Course.name.ilike(name)))
    ).scalars().first()

    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_COURSE_ERROR.format(name=name),
        )


@router.get("/", response_model=list[CourseResponse])
async def get_courses(db: DbSession) -> Sequence[Course]:
    return (await db.execute(select(Course).order_by(Course.name))).scalars().all()


@router.post("/", response_model=CourseResponse)
async def create_course(payload: CourseCreate, db: DbSession) -> Course:
    await _assert_name_available(db, payload.name)

    course = Course(**payload.model_dump())

    try:
        db.add(course)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CREATE_ERROR,
        ) from err

    return course


@router.get("/{name}", response_model=CourseResponse)
async def get_course(name: str, db: DbSession) -> Course:
    return await _get_course_or_404(db, name)


@router.put("/{name}", response_model=CourseResponse)
async def update_course(
    name: str,
    payload: CourseUpdate,
    db: DbSession,
) -> Course:
    course = await _get_course_or_404(db, name)

    if course.name.lower() != payload.name.lower():
        await _assert_name_available(db, payload.name)

    # Renaming rewrites the PK; course_participants.course_type follows through
    # its onupdate="CASCADE".
    course.name = payload.name
    course.description = payload.description
    course.cost = payload.cost

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UPDATE_ERROR,
        ) from err

    return course


@router.delete("/{name}")
async def delete_course(name: str, db: DbSession) -> dict[str, str]:
    course = await _get_course_or_404(db, name)

    try:
        await db.delete(course)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}
