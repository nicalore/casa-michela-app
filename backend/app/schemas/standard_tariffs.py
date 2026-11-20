from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.core.i18n import tr
from app.models.study_program import EducationLevelEnum

_MAX_AMOUNT_CENTS: Final[int] = 10_000_000

_MAX_PACKAGE_HOURS: Final[int] = 1000

_PACKAGE_PRICE_ERROR: Final[tuple[str, str]] = (
    "Mancano le ore o il costo del pacchetto.",
    "The package hours or cost are missing.",
)
_MONTHLY_PRICE_ERROR: Final[tuple[str, str]] = (
    "Manca la quota mensile.",
    "The monthly fee is missing.",
)
_PACKAGE_PAIR_ERROR: Final[tuple[str, str]] = (
    "Ore e costo del pacchetto vanno insieme.",
    "Package hours and cost go together.",
)
_ONE_ENABLED_ERROR: Final[tuple[str, str]] = (
    "Almeno una tariffa deve restare attiva.",
    "At least one rate must stay active.",
)


class StandardTariffData(BaseModel):
    hourly_enabled: bool
    hourly_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    package_enabled: bool
    package_cents: int | None = Field(None, gt=0, le=_MAX_AMOUNT_CENTS)
    package_hours: int | None = Field(None, gt=0, le=_MAX_PACKAGE_HOURS)
    monthly_enabled: bool
    monthly_cents: int | None = Field(None, gt=0, le=_MAX_AMOUNT_CENTS)
    weekend_online_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)

    @model_validator(mode="after")
    def _priced_when_enabled(self) -> Self:
        if (self.package_cents is None) != (self.package_hours is None):
            raise ValueError(tr(*_PACKAGE_PAIR_ERROR))

        if not (self.hourly_enabled or self.package_enabled or self.monthly_enabled):
            raise ValueError(tr(*_ONE_ENABLED_ERROR))

        if self.package_enabled and self.package_cents is None:
            raise ValueError(tr(*_PACKAGE_PRICE_ERROR))

        if self.monthly_enabled and self.monthly_cents is None:
            raise ValueError(tr(*_MONTHLY_PRICE_ERROR))

        return self


class StandardTariffResponse(StandardTariffData):
    level: EducationLevelEnum


class AnnualFeesData(BaseModel):
    membership_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    insurance_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)


class StandardTariffsResponse(BaseModel):
    # Primary, middle and high school, in this order.
    levels: list[StandardTariffResponse]
    fees: AnnualFeesData
