from datetime import date
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.schemas.booking import BookingBase
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.validators import TimeBandMixin

_OVERLAPPING_SLOTS_ERROR: Final[str] = (
    "Gli orari di presenza indicati si sovrappongono fra loro."
)

_DUPLICATE_MODE_ERROR: Final[str] = (
    "Ogni modalità va indicata una volta sola nella stessa richiesta."
)


class LessonRequestSlot(TimeBandMixin):
    pass


class LessonRequestSubject(BookingBase):
    pass


class LessonRequestMode(BaseModel):
    mode: OpeningModeEnum
    slots: list[LessonRequestSlot] = Field(..., min_length=1)

    subjects: list[LessonRequestSubject] = Field(default_factory=list)

    @model_validator(mode="after")
    def _slots_do_not_overlap(self) -> Self:
        ordered = sorted(self.slots, key=lambda slot: slot.start_time)

        for earlier, later in zip(ordered, ordered[1:], strict=False):
            if later.start_time < earlier.end_time:
                raise ValueError(_OVERLAPPING_SLOTS_ERROR)

        return self


class LessonRequestCreate(BaseModel):
    student_tax_code: str
    booker_tax_code: str | None = None

    date: date
    modes: list[LessonRequestMode] = Field(..., min_length=1, max_length=2)

    @model_validator(mode="after")
    def _modes_are_distinct(self) -> Self:
        seen = {block.mode for block in self.modes}

        if len(seen) != len(self.modes):
            raise ValueError(_DUPLICATE_MODE_ERROR)

        return self
