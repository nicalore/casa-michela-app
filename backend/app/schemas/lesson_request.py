from datetime import date
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.schemas.booking import BookingBase
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.validators import TimeBandMixin

_OVERLAPPING_SLOTS_ERROR: Final[str] = (
    "Le fasce di presenza indicate si sovrappongono fra loro."
)

_DUPLICATE_MODE_ERROR: Final[str] = (
    "Ogni modalità va indicata una volta sola nella stessa richiesta."
)


# One stretch of the day the pupil gives, inside the association's hours.
class LessonRequestSlot(TimeBandMixin):
    pass


# One lesson asked for: what, how long, and who should teach it.
class LessonRequestSubject(BookingBase):
    pass


# One mode of the day: its bands and the hours asked for inside them. The two
# modes are two answers to the same day and are given together, yet stay counted
# apart: an hour of Latin asked online is not taught out of the two hours the
# pupil spends in the building.
class LessonRequestMode(BaseModel):
    mode: OpeningModeEnum
    slots: list[LessonRequestSlot] = Field(..., min_length=1)

    # Optional: subjects *may* be given, and a presence without lessons is
    # already a valid row.
    subjects: list[LessonRequestSubject] = Field(default_factory=list)

    @model_validator(mode="after")
    def _slots_do_not_overlap(self) -> Self:
        # The service checks against what is already stored too; this only
        # catches a request contradicting itself, without touching the database.
        ordered = sorted(self.slots, key=lambda slot: slot.start_time)

        for earlier, later in zip(ordered, ordered[1:], strict=False):
            if later.start_time < earlier.end_time:
                raise ValueError(_OVERLAPPING_SLOTS_ERROR)

        return self


# A whole day booked in one go, in one or both modes: one student, one date,
# and for each requested mode its bands and its lessons. The request either
# passes as a whole or not at all.
class LessonRequestCreate(BaseModel):
    student_tax_code: str
    # Admin-only: a non-admin caller's value is ignored server-side in favor
    # of their own tax code, same as PresenceCreate.
    booker_tax_code: str | None = None

    date: date
    modes: list[LessonRequestMode] = Field(..., min_length=1, max_length=2)

    @model_validator(mode="after")
    def _modes_are_distinct(self) -> Self:
        seen = {block.mode for block in self.modes}

        if len(seen) != len(self.modes):
            raise ValueError(_DUPLICATE_MODE_ERROR)

        return self
