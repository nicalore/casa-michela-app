from datetime import date
from enum import StrEnum
from typing import Final

from pydantic import BaseModel, Field

from app.core import field_lengths
from app.schemas.person_wizard import PersonWizardPayloadBase

# The form has a genitore1 block and a genitore2 block and nowhere to put a
# third; the wizard caps the picker at the same number.
_MAX_PARENTS: Final[int] = 2


# One per tickable cell of the Aiuto Compiti rate table. No model backs it:
# the rate is printed on the form and nowhere else.
class HomeworkTariffEnum(StrEnum):
    PRIMARY_MONTHLY = "PRIMARY_MONTHLY"
    MIDDLE_HOURLY = "MIDDLE_HOURLY"
    MIDDLE_PACKAGE = "MIDDLE_PACKAGE"
    HIGH_HOURLY = "HIGH_HOURLY"
    HIGH_PACKAGE = "HIGH_PACKAGE"


# Every field is optional, unlike WizardGeneralData: a parent already on file
# may carry a gap, and a form with a hole in it still prints. The key names are
# the ones the wizard already builds for general_data.
class EnrollmentFormParent(BaseModel):
    first_name: str | None = Field(None, max_length=field_lengths.PERSON_NAME)
    last_name: str | None = Field(None, max_length=field_lengths.PERSON_NAME)
    tax_code: str | None = Field(None, max_length=field_lengths.TAX_CODE)
    gender: str | None = None
    birth_date: date | None = None
    birth_city: str | None = Field(None, max_length=field_lengths.CITY)
    birth_nation: str | None = Field(None, max_length=field_lengths.NATION)
    birth_province: str | None = Field(None, max_length=field_lengths.PROVINCE)
    residence_type: str | None = Field(None, max_length=field_lengths.RESIDENCE_TYPE)
    residence_address: str | None = Field(None, max_length=field_lengths.ADDRESS)
    residence_street_number: str | None = Field(
        None,
        max_length=field_lengths.STREET_NUMBER,
    )
    residence_city: str | None = Field(None, max_length=field_lengths.CITY)
    residence_province: str | None = Field(None, max_length=field_lengths.PROVINCE)
    postal_code: str | None = Field(None, max_length=field_lengths.POSTAL_CODE)
    email: str | None = Field(None, max_length=field_lengths.EMAIL)
    phone: str | None = Field(None, max_length=field_lengths.PHONE)


class EnrollmentFormRequest(BaseModel):
    person: PersonWizardPayloadBase

    # In the order the wizard picked them.
    parents: list[EnrollmentFormParent] = Field(
        default_factory=list,
        max_length=_MAX_PARENTS,
    )

    # Which box to tick in the Aiuto Compiti rate table. It sits out here
    # rather than under `person` because it is printed and then forgotten:
    # nothing about the rate reaches the register.
    homework_tariff: HomeworkTariffEnum | None = None
