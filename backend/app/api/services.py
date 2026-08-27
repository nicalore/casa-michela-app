from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.models.service import Service
from app.schemas.service import ServiceCreate, ServiceResponse, ServiceUpdate

router = APIRouter(prefix="/services", tags=["services"])

_SERVICE_NOT_FOUND_ERROR: Final[str] = "Servizio non trovato."
_DUPLICATE_SERVICE_ERROR: Final[str] = 'Esiste già il servizio "{name}"'
_CREATE_ERROR: Final[str] = "Errore durante la creazione del servizio."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare il servizio in quanto protetto da vincoli referenziali."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Servizio eliminato"


async def _get_service_or_404(db: AsyncSession, name: str) -> Service:
    service = (
        await db.execute(select(Service).where(Service.name == name))
    ).scalars().first()

    if service is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SERVICE_NOT_FOUND_ERROR,
        )

    return service


async def _assert_name_available(db: AsyncSession, name: str) -> None:
    # Case-insensitive like the other catalogues; the PK alone would let
    # "Tesina" and "tesina" both through.
    existing = (
        await db.execute(select(Service).where(Service.name.ilike(name)))
    ).scalars().first()

    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_SERVICE_ERROR.format(name=name),
        )


@router.get("/", response_model=list[ServiceResponse])
async def get_services(db: DbSession) -> Sequence[Service]:
    return (await db.execute(select(Service).order_by(Service.name))).scalars().all()


@router.post("/", response_model=ServiceResponse)
async def create_service(payload: ServiceCreate, db: DbSession) -> Service:
    await _assert_name_available(db, payload.name)

    service = Service(**payload.model_dump())

    try:
        db.add(service)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CREATE_ERROR,
        ) from err

    return service


@router.get("/{name}", response_model=ServiceResponse)
async def get_service(name: str, db: DbSession) -> Service:
    return await _get_service_or_404(db, name)


@router.put("/{name}", response_model=ServiceResponse)
async def update_service(
    name: str,
    payload: ServiceUpdate,
    db: DbSession,
) -> Service:
    service = await _get_service_or_404(db, name)

    if service.name.lower() != payload.name.lower():
        await _assert_name_available(db, payload.name)

    # Renaming rewrites the PK; any future FK to services needs
    # onupdate="CASCADE" for this to keep working.
    service.name = payload.name
    service.description = payload.description

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UPDATE_ERROR,
        ) from err

    return service


@router.delete("/{name}")
async def delete_service(name: str, db: DbSession) -> dict[str, str]:
    service = await _get_service_or_404(db, name)

    try:
        await db.delete(service)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}
