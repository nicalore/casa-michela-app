from datetime import date
from typing import Final, Literal, Self

from pydantic import BaseModel, Field, model_validator

from app.models.member import PaymentMethodEnum
from app.models.student_payment import HoursKindEnum
from app.models.student_tariff import TariffKindEnum
from app.models.study_program import EducationLevelEnum

_PACKAGE_HOURS_ERROR: Final[str] = "Le ore si indicano solo per il pacchetto."

_OTHER_METHOD_ERROR: Final[str] = "La modalità si scrive solo per «Altro»."

_HOURLY_PAID_ERROR: Final[str] = "La tariffa a ore non si paga all’iscrizione."

_MAX_AMOUNT_CENTS: Final[int] = 10_000_000

_MAX_PACKAGE_HOURS: Final[int] = 1000

_MAX_METHOD_LENGTH: Final[int] = 255

_QUARTER_HOUR: Final[int] = 15

_PAID_TOO_EARLY_ERROR: Final[str] = "La data del pagamento non è valida."

# The association's first day, as services.worked_hours.BEGINNING: no payment is
# older, and a mistyped year lands before it.
_FIRST_DAY: Final[date] = date(2023, 1, 1)


class StudentTariffData(BaseModel):
    kind: TariffKindEnum
    amount_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    package_hours: int | None = Field(None, gt=0, le=_MAX_PACKAGE_HOURS)

    @model_validator(mode="after")
    def _hours_only_for_packages(self) -> Self:
        if (self.kind == TariffKindEnum.PACKAGE) != (self.package_hours is not None):
            raise ValueError(_PACKAGE_HOURS_ERROR)

        return self


# The creation wizard's: a package or the month's fee may be paid there and then.
class WizardTariffData(StudentTariffData):
    paid: bool = False

    @model_validator(mode="after")
    def _hourly_never_paid(self) -> Self:
        if self.paid and self.kind == TariffKindEnum.HOURLY:
            raise ValueError(_HOURLY_PAID_ERROR)

        return self


class PaymentData(BaseModel):
    paid_on: date
    payment_method: PaymentMethodEnum
    payment_method_other: str | None = Field(
        None,
        min_length=1,
        max_length=_MAX_METHOD_LENGTH,
    )

    @model_validator(mode="after")
    def _other_only_for_other(self) -> Self:
        other = self.payment_method == PaymentMethodEnum.OTHER

        if other != (self.payment_method_other is not None):
            raise ValueError(_OTHER_METHOD_ERROR)

        return self

    @model_validator(mode="after")
    def _not_before_the_association(self) -> Self:
        if self.paid_on < _FIRST_DAY:
            raise ValueError(_PAID_TOO_EARLY_ERROR)

        return self


# A package or a month's fee bought again; the kind is the one running.
class RenewalData(BaseModel):
    amount_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    package_hours: int | None = Field(None, gt=0, le=_MAX_PACKAGE_HOURS)
    payment: PaymentData


class TariffChangeData(StudentTariffData):
    # The day, for an hourly rate or a package after hours.
    starts_on: date | None = None
    # From next month rather than this one, where months decide.
    next_month: bool = False
    # Required when the new tariff is a package or a monthly fee.
    payment: PaymentData | None = None


# Hours paid before they are done, by the quarter hour, as lessons are booked.
class AheadData(BaseModel):
    minutes: int = Field(
        ...,
        gt=0,
        le=_MAX_PACKAGE_HOURS * 60,
        multiple_of=_QUARTER_HOUR,
    )
    cents_per_hour: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    payment: PaymentData


class SettlementData(BaseModel):
    hours_kind: HoursKindEnum
    # Ignored online at the weekend, which has its own.
    cents_per_hour: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    payment: PaymentData
    # The minutes the window showed: another band confirmed meanwhile adds to the
    # line, and what is settled must be what was read.
    expected_minutes: int | None = Field(None, ge=0)


class StudentTariffResponse(BaseModel):
    kind: TariffKindEnum
    # What the next package or month costs: the last bought, else the agreed one.
    amount_cents: int
    package_hours: int | None
    # When it began to count, which a package before it may have delayed.
    starts_on: date


class LessonPartResponse(BaseModel):
    day: date
    minutes: int
    # Under the tariff running now.
    current: bool


class HoursLineResponse(BaseModel):
    kind: HoursKindEnum
    minutes: int
    cents: int
    cents_per_hour: int
    parts: list[LessonPartResponse]


class PackageStatusResponse(BaseModel):
    total_minutes: int
    used_minutes: int
    # The day of the lesson that used the last minute.
    ended_on: date | None


# The hours paid ahead not used up yet, however many payments.
class AheadStatusResponse(BaseModel):
    total_minutes: int
    used_minutes: int


class MonthStateResponse(BaseModel):
    month: date
    state: Literal["PAID", "DUE", "NONE"]


class HistoryLessonResponse(BaseModel):
    day: date
    minutes: int
    # The whole lesson's, more than `minutes` when another payment has the rest.
    lesson_minutes: int
    # Packages: what is left after it.
    left_minutes: int | None
    # Hours paid by the hour: what it costs.
    cents: int | None
    # The lesson that used a package's last minute.
    exhausted: bool
    # Before it was paid: taken at the package's renewal or with the hours paid ahead.
    before_payment: bool


class HistoryRowResponse(BaseModel):
    kind: Literal[
        "PACKAGE",
        "MONTH",
        "AHEAD",
        "HOURLY",
        "OVER_PACKAGE",
        "OVER_FEE",
        "WEEKEND_ONLINE",
        "MEMBERSHIP_FEE",
        "INSURANCE_FEE",
    ]
    # Null while still to pay.
    paid_on: date | None
    payment_method: str | None
    payment_method_other: str | None
    amount_cents: int
    minutes: int
    package_hours: int | None
    # A month's fee; null while it waits for a package to end.
    month: date | None
    ahead_minutes: int | None
    # Packages and hours paid ahead; WAITING also for a fee after a package.
    state: Literal["RUNNING", "ENDED", "WAITING", "UNUSED"] | None
    # The newest first.
    lessons: list[HistoryLessonResponse]
    # Annual fees: the membership year and the row to settle.
    year: int | None = None
    fee_id: int | None = None
    # A payment made, which can be cancelled.
    payment_id: int | None = None


class StudentPaymentsResponse(BaseModel):
    # Members who are not pupils have only their annual fees.
    student: bool
    # Not enrolled: nothing new to buy, only what is owed to settle.
    read_only: bool
    tariff: StudentTariffResponse | None
    school_level: EducationLevelEnum | None
    # The last payment's, else the one in the record.
    payment_method: str | None
    payment_method_other: str | None
    # Null without a tariff or a fee.
    state: Literal["OK", "DUE", "RENEW"] | None
    # Hours to settle and annual fees owed.
    due_cents: int
    # The package running, or the last one when all are used.
    package: PackageStatusResponse | None
    # The school year's months, only while the fee is monthly.
    months: list[MonthStateResponse] | None
    # Hours paid ahead and not used up, under an hourly tariff.
    ahead: AheadStatusResponse | None
    lines: list[HoursLineResponse]
    # Paid ahead and not started yet: one at a time.
    queued: Literal["PACKAGE", "MONTH", "CHANGE"] | None
    # The day a queued change starts; null: it waits for the package or the hours
    # paid ahead to end.
    queued_starts_on: date | None
    # The tariff a queued change brings in.
    queued_tariff: StudentTariffResponse | None = None
    # Every payment of every year, those still to pay first, then the newest.
    history: list[HistoryRowResponse]
