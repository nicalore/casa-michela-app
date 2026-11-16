from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.models.study_program import EducationLevelEnum
from app.schemas.standard_tariffs import (
    AnnualFeesData,
    StandardTariffData,
    StandardTariffResponse,
    StandardTariffsResponse,
)
from app.services import standard_tariffs as service

router = APIRouter(prefix="/standard-tariffs", tags=["standard-tariffs"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


async def _response(db: AsyncSession) -> StandardTariffsResponse:
    fees = await service.annual_fees(db)

    return StandardTariffsResponse(
        levels=[
            StandardTariffResponse(
                level=row.level,
                hourly_enabled=row.hourly_enabled,
                hourly_cents=row.hourly_cents,
                package_enabled=row.package_enabled,
                package_cents=row.package_cents,
                package_hours=row.package_hours,
                monthly_enabled=row.monthly_enabled,
                monthly_cents=row.monthly_cents,
                weekend_online_cents=row.weekend_online_cents,
            )
            for row in await service.standard_tariffs(db)
        ],
        fees=AnnualFeesData(
            membership_cents=fees.membership_cents,
            insurance_cents=fees.insurance_cents,
        ),
    )


@router.get("/", response_model=StandardTariffsResponse)
async def standard_tariffs(db: DbSession, _: Admin) -> StandardTariffsResponse:
    return await _response(db)


@router.put("/levels/{level}", response_model=StandardTariffsResponse)
async def update_level(
    level: EducationLevelEnum,
    payload: StandardTariffData,
    db: DbSession,
    _: Admin,
) -> StandardTariffsResponse:
    await service.update_standard_tariff(db, level, payload)
    await db.commit()

    return await _response(db)


@router.put("/fees", response_model=StandardTariffsResponse)
async def update_fees(
    payload: AnnualFeesData,
    db: DbSession,
    _: Admin,
) -> StandardTariffsResponse:
    await service.update_annual_fees(db, payload)
    await db.commit()

    return await _response(db)
