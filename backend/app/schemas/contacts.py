import re
from typing import Final

from pydantic import BaseModel, Field, field_validator

from app.core import field_lengths
from app.schemas.validators import CleanStr

# Both mirror the CHECKs on people: refused with a message instead of failing at commit.
_EMAIL_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$"
)
_PHONE_PATTERN: Final[re.Pattern[str]] = re.compile(r"^\+?[0-9]+$")

_EMAIL_FORMAT_ERROR: Final[str] = "Formato email non valido"
_PHONE_FORMAT_ERROR: Final[str] = "Il telefono può contenere solo cifre, con un + iniziale"


class ContactsUpdate(BaseModel):
    email: CleanStr = Field(..., max_length=field_lengths.EMAIL)
    phone: CleanStr = Field(..., max_length=field_lengths.PHONE)

    @field_validator("email")
    @classmethod
    def _email_format(cls, value: str) -> str:
        if not _EMAIL_PATTERN.match(value):
            raise ValueError(_EMAIL_FORMAT_ERROR)

        return value

    @field_validator("phone")
    @classmethod
    def _phone_format(cls, value: str) -> str:
        if not _PHONE_PATTERN.match(value):
            raise ValueError(_PHONE_FORMAT_ERROR)

        return value
