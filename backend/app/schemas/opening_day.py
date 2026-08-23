from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, computed_field, model_validator

from app.core import field_lengths
from app.core.holidays import holiday_label
from app.schemas.validators import OptionalCleanStr, OptionalTimeRangeMixin

_INVALID_RANGE_ERROR: Final[str] = (
    "La data finale deve essere uguale o successiva a quella iniziale."
)


class OpeningModeEnum(StrEnum):
    PRESENCE = "presence"
    ONLINE = "online"


class OpeningDayBase(OptionalTimeRangeMixin):
    date: date
    mode: OpeningModeEnum
    note: OptionalCleanStr = None


class OpeningDayCreate(OpeningDayBase):
    note: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)


class OpeningDayUpdate(OptionalTimeRangeMixin):
    note: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)
    expected_updated_at: datetime | None = None


class OpeningDayResponse(OpeningDayBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    is_override: bool
    created_at: datetime
    updated_at: datetime

    @computed_field
    @property
    def is_holiday(self) -> bool:
        if self.start_time is not None:
            return False

        label = holiday_label(self.date)

        return label is not None and label == self.note


class OpeningDayRestoreRequest(BaseModel):
    date_from: date
    date_to: date
    mode: OpeningModeEnum

    @model_validator(mode="after")
    def _range_ordered(self) -> Self:
        if self.date_to < self.date_from:
            raise ValueError(_INVALID_RANGE_ERROR)

        return self


class OpeningDayRestoreResponse(BaseModel):
    dates_restored: int
    rows_created: int
