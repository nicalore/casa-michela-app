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


# Order-preserving, so that a client listing the same discipline twice gets the
# lesson it meant rather than an error about a duplicate it cannot see.
def _drop_duplicates[T](values: list[T]) -> list[T]:
    return list(dict.fromkeys(values))


class LessonBase(TimeBandMixin):
    availability_id: int

    booking_ids: list[int] = Field(..., min_length=1)

    # Empty only for an hour made of services, which have no discipline behind
    # them at all.
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

    # Where the teacher is, and how the hour reaches the pupils. They differ
    # exactly when someone in the building is teaching someone who is not.
    teacher_mode: OpeningModeEnum
    mode: OpeningModeEnum

    band: TimeBandEnum
    start_time: time
    end_time: time

    # Not a property of the lesson but of its teacher's day: resolved through
    # teacher_room_assignments, and null for a teacher working from home.
    room: RoomOption | None = None

    disciplines: list[AssociationSubjectOption] = Field(default_factory=list)
    bookings: list[BookingResponse] = Field(default_factory=list)

    is_published: bool = False

    # Things worth telling the administrator that are not reasons to refuse:
    # a teacher someone would rather not have, a room over its capacity.
    # Populated on write, empty on read.
    warnings: list[str] = Field(default_factory=list)

    created_at: datetime
    updated_at: datetime
