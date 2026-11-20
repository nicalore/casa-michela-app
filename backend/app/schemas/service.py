from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core import field_lengths
from app.core.i18n import tr
from app.schemas.validators import OptionalCleanStr, StrippedStr

_BLANK_NAME_ERROR: Final[tuple[str, str]] = (
    "Il nome del servizio non può essere vuoto.",
    "The service name can't be empty.",
)


class ServiceBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)
    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )

    @field_validator("name")
    @classmethod
    def _name_not_blank(cls, value: str) -> str:
        if not value:
            raise ValueError(tr(*_BLANK_NAME_ERROR))

        return value


class ServiceCreate(ServiceBase):
    pass


class ServiceUpdate(ServiceBase):
    pass


class ServiceResponse(ServiceBase):
    model_config = ConfigDict(from_attributes=True)

    created_at: datetime
