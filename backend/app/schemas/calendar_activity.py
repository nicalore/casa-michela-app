from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, Field

from app.core import field_lengths
from app.core.time_band import TimeBandEnum
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.validators import (
    OptionalCleanStr,
    QuarterHourTimeRangeMixin,
    StrippedStr,
)


class CalendarActivityBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)

    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )


# Date and band are immutable after creation.
class CalendarActivityCreate(CalendarActivityBase):
    date: date

    band: TimeBandEnum


# All-or-none: null hands the activity back to the panel. Quarter-hour grid,
# with no minimum duration (unlike lessons).
class CalendarActivityAssignment(QuarterHourTimeRangeMixin):
    availability_id: int


class CalendarActivityUpdate(CalendarActivityBase):
    assignment: CalendarActivityAssignment | None = None

    expected_updated_at: datetime | None = None


class CalendarActivityPlacement(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    availability_id: int
    teacher_tax_code: str
    teacher: PersonOption

    teacher_mode: OpeningModeEnum

    start_time: time
    end_time: time


class CalendarActivityResponse(CalendarActivityBase):
    model_config = ConfigDict(from_attributes=True)

    id: int

    date: date
    band: TimeBandEnum

    placement: CalendarActivityPlacement | None = None

    is_locked: bool = False

    created_at: datetime
    updated_at: datetime
