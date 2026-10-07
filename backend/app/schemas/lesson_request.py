from datetime import date, datetime
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.core.time_band import TimeBandEnum, presence_band
from app.schemas.booking import BookingBase
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.validators import TimeBandMixin

_OVERLAPPING_SLOTS_ERROR: Final[str] = (
    "Gli orari di presenza indicati si sovrappongono fra loro."
)

_DUPLICATE_MODE_ERROR: Final[str] = (
    "Ogni modalità va indicata una volta sola nella stessa richiesta."
)

_BAND_MISSING_ERROR: Final[str] = (
    "Indica la fascia di ogni materia: ci sono orari in più fasce."
)

_BAND_WITHOUT_HOURS_ERROR: Final[str] = (
    "Una materia è indicata per una fascia in cui non ci sono orari di presenza."
)

_DUPLICATE_DAY_ERROR: Final[str] = (
    "Ogni giornata va indicata una volta sola nella stessa richiesta."
)


class LessonRequestSlot(TimeBandMixin):
    @model_validator(mode="after")
    def _within_one_band(self) -> Self:
        presence_band(self.start_time, self.end_time)

        return self

    @property
    def band(self) -> TimeBandEnum:
        return presence_band(self.start_time, self.end_time)


class LessonRequestSubject(BookingBase):
    # Planned only in this band's hours; may be left out when every slot shares one.
    band: TimeBandEnum | None = None


class _ModeHours(BaseModel):
    mode: OpeningModeEnum
    slots: list[LessonRequestSlot]
    subjects: list[LessonRequestSubject]

    @model_validator(mode="after")
    def _slots_do_not_overlap(self) -> Self:
        ordered = sorted(self.slots, key=lambda slot: slot.start_time)

        for earlier, later in zip(ordered, ordered[1:], strict=False):
            if later.start_time < earlier.end_time:
                raise ValueError(_OVERLAPPING_SLOTS_ERROR)

        return self

    @model_validator(mode="after")
    def _subjects_have_a_band(self) -> Self:
        bands = {slot.band for slot in self.slots}

        for subject in self.subjects:
            if subject.band is None:
                if len(bands) > 1:
                    raise ValueError(_BAND_MISSING_ERROR)

                if not bands:
                    raise ValueError(_BAND_WITHOUT_HOURS_ERROR)

                subject.band = next(iter(bands))

            elif subject.band not in bands:
                raise ValueError(_BAND_WITHOUT_HOURS_ERROR)

        return self


class LessonRequestMode(_ModeHours):
    slots: list[LessonRequestSlot] = Field(..., min_length=1)

    subjects: list[LessonRequestSubject] = Field(default_factory=list)


class LessonRequestRowVersion(BaseModel):
    id: int
    expected_updated_at: datetime


class LessonRequestReplaceSlot(LessonRequestSlot):
    # Set for a stored stretch that stays, possibly with new hours.
    presence_id: int | None = None
    expected_updated_at: datetime | None = None


class LessonRequestReplaceSubject(LessonRequestSubject):
    # Set for a stored subject that stays.
    booking_id: int | None = None
    expected_updated_at: datetime | None = None


# The mode's whole day to be; no slots clears it, closed bands stay untouched.
class LessonRequestReplaceMode(_ModeHours):
    slots: list[LessonRequestReplaceSlot] = Field(default_factory=list)

    subjects: list[LessonRequestReplaceSubject] = Field(default_factory=list)

    # Rows dropped as the writer saw them; one added or changed since stops the write.
    dropped_presences: list[LessonRequestRowVersion] = Field(default_factory=list)
    dropped_bookings: list[LessonRequestRowVersion] = Field(default_factory=list)


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


class LessonRequestReplaceDay(BaseModel):
    date: date
    modes: list[LessonRequestReplaceMode] = Field(..., min_length=1, max_length=2)

    @model_validator(mode="after")
    def _modes_are_distinct(self) -> Self:
        seen = {block.mode for block in self.modes}

        if len(seen) != len(self.modes):
            raise ValueError(_DUPLICATE_MODE_ERROR)

        return self


class LessonRequestReplace(LessonRequestReplaceDay):
    student_tax_code: str
    booker_tax_code: str | None = None


# A move: both days written together; a subject may name a stored one of either.
class LessonRequestReplaceDays(BaseModel):
    student_tax_code: str
    booker_tax_code: str | None = None

    days: list[LessonRequestReplaceDay] = Field(..., min_length=1, max_length=2)

    @model_validator(mode="after")
    def _days_are_distinct(self) -> Self:
        seen = {day.date for day in self.days}

        if len(seen) != len(self.days):
            raise ValueError(_DUPLICATE_DAY_ERROR)

        return self

    def per_day(self) -> list[LessonRequestReplace]:
        return [
            LessonRequestReplace(
                student_tax_code=self.student_tax_code,
                booker_tax_code=self.booker_tax_code,
                date=day.date,
                modes=day.modes,
            )
            for day in self.days
        ]
