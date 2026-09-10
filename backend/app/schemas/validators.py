from datetime import time
from typing import Annotated, Any, Final, Self

from pydantic import (
    AfterValidator,
    BaseModel,
    BeforeValidator,
    field_validator,
    model_validator,
)

from app.core.time_step import (
    MINIMUM_BAND_MINUTES,
    assert_quarter_hour_step,
    minutes_between,
)

END_BEFORE_START_ERROR: Final[str] = (
    "L'orario di fine deve essere successivo all'orario di inizio."
)

_INCONSISTENT_CLOSURE_ERROR: Final[str] = (
    "Se è chiuso, sia l'orario di inizio sia quello di fine devono essere "
    "assenti."
)

_BAND_TOO_SHORT_ERROR: Final[str] = "L'orario deve durare almeno mezz'ora."


def _strip(value: str) -> str:
    return value.strip()


def _strip_to_none(value: str | None) -> str | None:
    if value is None:
        return None

    stripped = value.strip()

    return stripped or None


def _strip_first(value: Any) -> Any:
    return value.strip() if isinstance(value, str) else value


StrippedStr = Annotated[str, AfterValidator(_strip)]

# Trims before the length checks, so a string of spaces fails min_length.
CleanStr = Annotated[str, BeforeValidator(_strip_first)]

OptionalCleanStr = Annotated[str | None, AfterValidator(_strip_to_none)]


class TimeRangeMixin(BaseModel):
    start_time: time
    end_time: time

    @model_validator(mode="after")
    def _end_after_start(self) -> Self:
        if self.end_time <= self.start_time:
            raise ValueError(END_BEFORE_START_ERROR)

        return self


class QuarterHourTimeRangeMixin(TimeRangeMixin):
    @field_validator("start_time", "end_time")
    @classmethod
    def _time_step_of_15(cls, value: time) -> time:
        return assert_quarter_hour_step(value)


class TimeBandMixin(QuarterHourTimeRangeMixin):
    @model_validator(mode="after")
    def _band_is_long_enough(self) -> Self:
        if minutes_between(self.start_time, self.end_time) < MINIMUM_BAND_MINUTES:
            raise ValueError(_BAND_TOO_SHORT_ERROR)

        return self


class OptionalTimeRangeMixin(BaseModel):
    start_time: time | None = None
    end_time: time | None = None

    @model_validator(mode="after")
    def _hours_consistency(self) -> Self:
        if (self.start_time is None) != (self.end_time is None):
            raise ValueError(_INCONSISTENT_CLOSURE_ERROR)

        if (
            self.start_time is not None
            and self.end_time is not None
            and self.end_time <= self.start_time
        ):
            raise ValueError(END_BEFORE_START_ERROR)

        return self
