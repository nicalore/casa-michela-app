from datetime import date, datetime, time
from typing import Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.time_band import TimeBandEnum
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.booking import BookingResponse
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.schemas.validators import TimeBandMixin

_NO_BOOKING_ERROR: Final[str] = (
    "Una lezione deve avere almeno una prenotazione."
)


def _drop_duplicates[T](values: list[T]) -> list[T]:
    return list(dict.fromkeys(values))


class LessonBase(TimeBandMixin):
    availability_id: int

    booking_ids: list[int] = Field(..., min_length=1)

    association_subject_ids: list[int] = Field(default_factory=list)

    @field_validator("booking_ids", "association_subject_ids")
    @classmethod
    def _unique(cls, values: list[int]) -> list[int]:
        return _drop_duplicates(values)

    @field_validator("booking_ids")
    @classmethod
    def _not_empty(cls, values: list[int]) -> list[int]:
        if not values:
            raise ValueError(_NO_BOOKING_ERROR)

        return values


class LessonCreate(LessonBase):
    pass


class LessonUpdate(LessonBase):
    expected_updated_at: datetime | None = None


class LessonResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    availability_id: int
    teacher_tax_code: str
    teacher: PersonOption
    date: date

    teacher_mode: OpeningModeEnum
    mode: OpeningModeEnum

    band: TimeBandEnum
    start_time: time
    end_time: time

    room: RoomOption | None = None

    disciplines: list[AssociationSubjectOption] = Field(default_factory=list)
    bookings: list[BookingResponse] = Field(default_factory=list)

    is_locked: bool = False

    warnings: list[str] = Field(default_factory=list)

    created_at: datetime
    updated_at: datetime
