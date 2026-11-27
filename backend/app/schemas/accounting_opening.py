from datetime import date
from decimal import Decimal
from typing import Any, Final, Literal, Self

from pydantic import BaseModel, Field, model_validator

from app.core.i18n import tr
from app.models.student_tariff import TariffKindEnum
from app.models.study_program import EducationLevelEnum
from app.schemas.student_payments import (
    AheadData,
    PaymentData,
    StudentTariffData,
)

_MAX_MINUTES: Final[int] = 1000 * 60

_QUARTER_HOUR: Final[int] = 15

_MAX_GROSS: Final[Decimal] = Decimal("99999999.99")

_PACKAGE_ONLY_ERROR: Final[tuple[str, str]] = (
    "Le ore del pacchetto si indicano solo per il pacchetto.",
    "Package hours apply only to the hours package.",
)
_HOURLY_ONLY_ERROR: Final[tuple[str, str]] = (
    "Le ore in anticipo si indicano solo per la tariffa a ore.",
    "Hours ahead apply only to the hourly rate.",
)
_PAID_ONLY_ERROR: Final[tuple[str, str]] = (
    "La tariffa a ore non ha un pagamento.",
    "The hourly rate has no payment.",
)
_LEFT_TOO_MANY_ERROR: Final[tuple[str, str]] = (
    "Le ore rimaste sono più di quelle del pacchetto.",
    "The hours left are more than the package's.",
)
_DUE_AND_AHEAD_ERROR: Final[tuple[str, str]] = (
    "Ore da pagare e in anticipo insieme non si danno.",
    "Hours due and hours ahead can't both be given.",
)
_DUE_WITHOUT_END_ERROR: Final[tuple[str, str]] = (
    "Le ore oltre il pacchetto si indicano solo a pacchetto esaurito.",
    "Hours beyond the package apply only once the package is used up.",
)
_MONTH_DUE_ERROR: Final[tuple[str, str]] = (
    "Con la quota mensile non ci sono ore da pagare.",
    "With the monthly fee there are no hours due.",
)
_LEFT_OF_ENDED_ERROR: Final[tuple[str, str]] = (
    "Un pacchetto esaurito non ha ore rimaste.",
    "A used-up package has no hours left.",
)


def _minutes(default: int = 0) -> Any:
    return Field(default, ge=0, le=_MAX_MINUTES, multiple_of=_QUARTER_HOUR)


class TeacherOpeningData(BaseModel):
    collaboration_type: Literal["VOLUNTEER", "PAID", "PCTO", "UNPAID"]
    # The hourly rate, paid collaborations only.
    gross_compensation: Decimal | None = Field(
        None,
        ge=0,
        le=_MAX_GROSS,
        decimal_places=2,
    )
    # Pay of the days before money_from, in that month: paid collaborations only.
    gross: Decimal | None = Field(None, ge=0, le=_MAX_GROSS, decimal_places=2)


# How the pupil stood the day before money_from.
class PupilOpeningData(StudentTariffData):
    # The package or the month's fee; null when still to pay.
    payment: PaymentData | None = None
    package_ended: bool = False
    # Package not used up: what was left of it.
    left_minutes: int = _minutes()
    # By the hour, or beyond the package used up.
    due_minutes: int = _minutes()
    ahead: AheadData | None = None
    weekend_minutes: int = _minutes()

    @model_validator(mode="after")
    def _fits_the_kind(self) -> Self:
        package = self.kind == TariffKindEnum.PACKAGE
        hourly = self.kind == TariffKindEnum.HOURLY

        if not package and (self.package_ended or self.left_minutes):
            raise ValueError(tr(*_PACKAGE_ONLY_ERROR))

        if self.package_ended and self.left_minutes:
            raise ValueError(tr(*_LEFT_OF_ENDED_ERROR))

        if not hourly and self.ahead is not None:
            raise ValueError(tr(*_HOURLY_ONLY_ERROR))

        if hourly and self.payment is not None:
            raise ValueError(tr(*_PAID_ONLY_ERROR))

        if self.kind == TariffKindEnum.MONTHLY and self.due_minutes:
            raise ValueError(tr(*_MONTH_DUE_ERROR))

        if package and self.package_hours is not None:
            if self.left_minutes > self.package_hours * 60:
                raise ValueError(tr(*_LEFT_TOO_MANY_ERROR))

            if self.due_minutes and not self.package_ended:
                raise ValueError(tr(*_DUE_WITHOUT_END_ERROR))

        if self.due_minutes and self.ahead is not None:
            raise ValueError(tr(*_DUE_AND_AHEAD_ERROR))

        return self


class OpeningPersonResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    gender: str | None
    profile_image_url: str | None
    confirmed: bool


class OpeningTeacherResponse(OpeningPersonResponse):
    # As they stand in the month of money_from.
    collaboration_type: str
    gross_rate: Decimal | None
    # A board member stays unpaid: nothing to choose.
    can_edit: bool
    # Confirmed only.
    gross: Decimal | None


class OpeningTariffResponse(BaseModel):
    kind: TariffKindEnum
    amount_cents: int
    package_hours: int | None


class OpeningPaymentResponse(BaseModel):
    paid_on: date
    payment_method: str
    payment_method_other: str | None


class OpeningAheadResponse(BaseModel):
    minutes: int
    cents_per_hour: int
    payment: OpeningPaymentResponse


class StandardOfLevelResponse(BaseModel):
    hourly_cents: int
    package_cents: int | None
    package_hours: int | None
    monthly_cents: int | None


class OpeningPupilResponse(OpeningPersonResponse):
    school_level: EducationLevelEnum | None
    enabled_kinds: list[TariffKindEnum]
    standard: StandardOfLevelResponse | None
    # Hours beyond a package, and online at the weekend.
    settle_cents: int
    weekend_online_cents: int
    # In force the day before money_from.
    tariff: OpeningTariffResponse | None
    # What the confirmed set-up said.
    payment: OpeningPaymentResponse | None
    package_ended: bool
    left_minutes: int
    due_minutes: int
    ahead: OpeningAheadResponse | None
    weekend_minutes: int


class AccountingOpeningResponse(BaseModel):
    money_from: date
    closed: bool
    teachers: list[OpeningTeacherResponse]
    pupils: list[OpeningPupilResponse]
