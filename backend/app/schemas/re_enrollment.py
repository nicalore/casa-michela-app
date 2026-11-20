from datetime import date
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.core import field_lengths
from app.core.i18n import tr
from app.models.member import PaymentMethodEnum
from app.schemas.membership_fees import WizardFeesData
from app.schemas.person import SchoolEnrollmentUpdateItem
from app.schemas.student_payments import WizardTariffData

_OTHER_METHOD_ERROR: Final[tuple[str, str]] = (
    "La modalità si scrive solo per «Altro».",
    "The method is written only for “Other”.",
)


# A new year's membership, asked like at creation: method, fees and, for a pupil,
# the tariff (and the school year in course when it is not on record).
class ReEnrollmentPayload(BaseModel):
    start_date: date
    payment_method: PaymentMethodEnum
    payment_method_other: str | None = Field(
        None,
        min_length=1,
        max_length=field_lengths.OTHER_DETAIL,
    )
    fees: WizardFeesData
    tariff: WizardTariffData | None = None
    # The pupil's whole school history, sent only when it changes.
    school_enrollments: list[SchoolEnrollmentUpdateItem] | None = None

    @model_validator(mode="after")
    def _other_only_for_other(self) -> Self:
        other = self.payment_method == PaymentMethodEnum.OTHER

        if other != (self.payment_method_other is not None):
            raise ValueError(tr(*_OTHER_METHOD_ERROR))

        return self
