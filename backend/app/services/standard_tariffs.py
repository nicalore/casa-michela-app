from dataclasses import dataclass
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.standard_tariff import AnnualFees, StandardTariff
from app.models.student_tariff import TariffKindEnum
from app.models.study_program import EducationLevelEnum
from app.schemas.standard_tariffs import AnnualFeesData, StandardTariffData

LEVEL_ORDER: Final[tuple[EducationLevelEnum, ...]] = (
    EducationLevelEnum.PRIMARY_SCHOOL,
    EducationLevelEnum.MIDDLE_SCHOOL,
    EducationLevelEnum.HIGH_SCHOOL,
)


@dataclass(frozen=True)
class PaymentRates:
    # Hours outside a package or fee, even while the hourly tariff is off.
    settle_cents: int
    weekend_online_cents: int


# A pupil with no school level on record.
FALLBACK_RATES: Final[PaymentRates] = PaymentRates(1300, 1800)

_FEES_ID: Final[int] = 1


async def standard_tariffs(db: AsyncSession) -> list[StandardTariff]:
    rows = {row.level: row for row in await db.scalars(select(StandardTariff))}

    return [rows[level] for level in LEVEL_ORDER if level in rows]


async def standard_tariff(
    db: AsyncSession,
    level: EducationLevelEnum | None,
) -> StandardTariff | None:
    if level is None:
        return None

    return await db.get(StandardTariff, level)


def rates_of(row: StandardTariff | None) -> PaymentRates:
    if row is None:
        return FALLBACK_RATES

    return PaymentRates(
        settle_cents=row.hourly_cents,
        weekend_online_cents=row.weekend_online_cents,
    )


async def payment_rates(
    db: AsyncSession,
    level: EducationLevelEnum | None,
) -> PaymentRates:
    return rates_of(await standard_tariff(db, level))


def enabled_kinds(row: StandardTariff | None) -> set[TariffKindEnum]:
    """Every kind when the level is unknown."""
    if row is None:
        return set(TariffKindEnum)

    enabled = {
        TariffKindEnum.HOURLY: row.hourly_enabled,
        TariffKindEnum.PACKAGE: row.package_enabled,
        TariffKindEnum.MONTHLY: row.monthly_enabled,
    }

    return {kind for kind, on in enabled.items() if on}


async def update_standard_tariff(
    db: AsyncSession,
    level: EducationLevelEnum,
    data: StandardTariffData,
) -> StandardTariff:
    row = await db.get(StandardTariff, level)

    if row is None:
        row = StandardTariff(level=level)
        db.add(row)

    for name, value in data.model_dump().items():
        setattr(row, name, value)

    await db.flush()

    return row


async def annual_fees(db: AsyncSession) -> AnnualFees:
    row = await db.get(AnnualFees, _FEES_ID)

    if row is None:
        row = AnnualFees(id=_FEES_ID, membership_cents=1500, insurance_cents=2000)
        db.add(row)
        await db.flush()

    return row


async def update_annual_fees(db: AsyncSession, data: AnnualFeesData) -> AnnualFees:
    row = await annual_fees(db)
    row.membership_cents = data.membership_cents
    row.insurance_cents = data.insurance_cents
    await db.flush()

    return row
