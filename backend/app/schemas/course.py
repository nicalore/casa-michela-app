from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core import field_lengths
from app.schemas.validators import OptionalCleanStr, StrippedStr

_BLANK_NAME_ERROR: Final[str] = "Il nome del corso non può essere vuoto."


class CourseBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)
    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )
    cost: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.COST,
    )

    @field_validator("name")
    @classmethod
    def _name_not_blank(cls, value: str) -> str:
        if not value:
            raise ValueError(_BLANK_NAME_ERROR)

        return value


class CourseCreate(CourseBase):
    pass


class CourseUpdate(CourseBase):
    pass


class CourseResponse(CourseBase):
    model_config = ConfigDict(from_attributes=True)

    created_at: datetime
