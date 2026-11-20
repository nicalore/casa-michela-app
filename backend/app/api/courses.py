from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.rbac import get_current_identity, require_role
from app.core.i18n import tr
from app.models.course import Course
from app.schemas.course import CourseCreate, CourseResponse, CourseUpdate

router = APIRouter(
    prefix="/courses",
    tags=["courses"],
    # Reading takes a login; writing an administrator, route by route.
    dependencies=[Depends(get_current_identity)],
)

_COURSE_NOT_FOUND_ERROR: Final[tuple[str, str]] = (
    "Corso non trovato.",
    "Course not found.",
)
_DUPLICATE_COURSE_ERROR: Final[tuple[str, str]] = (
    'Esiste già il corso "{name}"',
    "The course “{name}” already exists",
)
_CREATE_ERROR: Final[tuple[str, str]] = (
    "Errore durante la creazione del corso.",
    "Error while creating the course.",
)
_UPDATE_ERROR: Final[tuple[str, str]] = (
    "Errore durante l'aggiornamento.",
    "Error while updating.",
)
_DELETE_CONSTRAINT_ERROR: Final[tuple[str, str]] = (
    "Impossibile eliminare il corso in quanto protetto da vincoli referenziali.",
    "Can't delete the course because other data refers to it.",
)
_DELETE_SUCCESS_DETAIL: Final[tuple[str, str]] = (
    "Corso eliminato",
    "Course deleted",
)


async def _get_course_or_404(db: AsyncSession, name: str) -> Course:
    course = (
        await db.execute(select(Course).where(Course.name == name))
    ).scalars().first()

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=tr(*_COURSE_NOT_FOUND_ERROR),
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
            detail=tr(*_DUPLICATE_COURSE_ERROR).format(name=name),
        )


@router.get("/", response_model=list[CourseResponse])
async def get_courses(db: DbSession) -> Sequence[Course]:
    return (await db.execute(select(Course).order_by(Course.name))).scalars().all()


@router.post(
    "/",
    response_model=CourseResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
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
            detail=tr(*_CREATE_ERROR),
        ) from err

    return course


@router.get("/{name}", response_model=CourseResponse)
async def get_course(name: str, db: DbSession) -> Course:
    return await _get_course_or_404(db, name)


@router.put(
    "/{name}",
    response_model=CourseResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
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
            detail=tr(*_UPDATE_ERROR),
        ) from err

    return course


@router.delete(
    "/{name}",
    dependencies=[Depends(require_role("ADMIN"))],
)
async def delete_course(name: str, db: DbSession) -> dict[str, str]:
    course = await _get_course_or_404(db, name)

    try:
        await db.delete(course)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_DELETE_CONSTRAINT_ERROR),
        ) from err

    return {"detail": tr(*_DELETE_SUCCESS_DETAIL)}
