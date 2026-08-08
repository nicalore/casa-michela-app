from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, computed_field, model_validator

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
    pass


# date, mode and is_override are immutable through the API: date/mode keep the
# propagation matching well defined (see WeeklyTemplateService), while
# is_override is forced to True server-side on every manual write.
class OpeningDayUpdate(OptionalTimeRangeMixin):
    note: OptionalCleanStr = None
    expected_updated_at: datetime | None = None


class OpeningDayResponse(OpeningDayBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    is_override: bool
    created_at: datetime
    updated_at: datetime

    # Whether the row is a system-generated public holiday closure. No column
    # says so: holidays are seeded as ordinary overrides, and are recognised by
    # being a whole-day closure whose note matches the name of the holiday
    # falling on that date. The client uses it to hide edit and delete on a
    # variation the next generation would recreate anyway.
    #
    # The comparison starts from the label and not from the note: an
    # extraordinary closure without a note has note None, and on an ordinary day
    # so is holiday_label — comparing them directly turned every note-less
    # closure into a holiday.
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
