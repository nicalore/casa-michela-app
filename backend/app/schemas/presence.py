from datetime import date, datetime
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.time_band import presence_band
from app.schemas.booking import BookingSummaryResponse
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.validators import TimeBandMixin


class PresenceBase(TimeBandMixin):
    date: date

    # A pupil can give both modes for the same day.
    mode: OpeningModeEnum

    @model_validator(mode="after")
    def _within_one_band(self) -> Self:
        presence_band(self.start_time, self.end_time)

        return self


class PresenceCreate(PresenceBase):
    student_tax_code: str
    # Admin-only: a non-admin caller's value is replaced by their own tax code.
    booker_tax_code: str | None = None


class PresenceUpdate(PresenceBase):
    # None = unchanged, same admin-only-reassignment semantics as Create.
    student_tax_code: str | None = None
    booker_tax_code: str | None = None
    expected_updated_at: datetime | None = None


class CompetenceWaiverResponse(BaseModel):
    booking_id: int
    teacher_tax_code: str


class PresenceResponse(PresenceBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    student_tax_code: str
    student: PersonOption
    booker_tax_code: str
    booker: PersonOption
    bookings: list[BookingSummaryResponse]
    # The pupil's standing list, for the wizard to leave them out of the offer.
    not_preferred_teachers: list[PersonOption] = Field(default_factory=list)
    # Admins only: to anyone else it would name the teacher of a draft calendar.
    competence_waivers: list[CompetenceWaiverResponse] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
