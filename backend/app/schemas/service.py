from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.validators import OptionalCleanStr, StrippedStr

_BLANK_NAME_ERROR: Final[str] = "Il nome del servizio non può essere vuoto."


class ServiceBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=255)
    description: OptionalCleanStr = Field(None, max_length=1000)

    @field_validator("name")
    @classmethod
    def _name_not_blank(cls, value: str) -> str:
        # min_length is measured before StrippedStr trims, so a name of nothing
        # but spaces gets past it and only the CHECK in the database stops it —
        # with a message that says nothing useful.
        if not value:
            raise ValueError(_BLANK_NAME_ERROR)

        return value


class ServiceCreate(ServiceBase):
    pass


class ServiceUpdate(ServiceBase):
    pass


class ServiceResponse(ServiceBase):
    model_config = ConfigDict(from_attributes=True)

    created_at: datetime
