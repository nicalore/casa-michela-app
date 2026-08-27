from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, computed_field, model_validator

from app.core import field_lengths
from app.core.holidays import holiday_label
from app.schemas.validators import (
    OptionalCleanStr,
    OptionalTimeRangeMixin,
    TimeRangeMixin,
)

_INVALID_RANGE_ERROR: Final[str] = (
    "La data finale deve essere uguale o successiva a quella iniziale."
)

_OVERLAPPING_BANDS_ERROR: Final[str] = (
    "Le fasce orarie di una giornata non possono sovrapporsi."
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


class OpeningDayBand(TimeRangeMixin):
    pass


# Replaces the whole day's rows at once: a row-by-row rewrite would leave the
# day transiently closed, clearing its lessons and unpublishing its calendar.
class OpeningDayReplace(BaseModel):
    date: date
    mode: OpeningModeEnum
    note: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)

    # Without confirm, a write that would unpublish a calendar is refused.
    confirm: bool = False

    # Empty means the day is closed.
    bands: list[OpeningDayBand] = Field(default_factory=list)

    @model_validator(mode="after")
    def _bands_do_not_overlap(self) -> Self:
        ordered = sorted(self.bands, key=lambda band: band.start_time)

        for earlier, later in zip(ordered, ordered[1:], strict=False):
            if later.start_time < earlier.end_time:
                raise ValueError(_OVERLAPPING_BANDS_ERROR)

        return self


class OpeningDayUpdate(OptionalTimeRangeMixin):
    note: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)
    expected_updated_at: datetime | None = None
    confirm: bool = False


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
    confirm: bool = False

    @model_validator(mode="after")
    def _range_ordered(self) -> Self:
        if self.date_to < self.date_from:
            raise ValueError(_INVALID_RANGE_ERROR)

        return self


class OpeningDayRestoreResponse(BaseModel):
    dates_restored: int
    rows_created: int
