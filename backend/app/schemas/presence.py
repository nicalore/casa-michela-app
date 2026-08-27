from datetime import date, datetime

from pydantic import ConfigDict

from app.schemas.booking import BookingSummaryResponse
from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.validators import TimeBandMixin


class PresenceBase(TimeBandMixin):
    date: date

    # A pupil can give both modes for the same day.
    mode: OpeningModeEnum


class PresenceCreate(PresenceBase):
    student_tax_code: str
    # Admin-only: a non-admin caller's value is ignored server-side in favor
    # of their own tax code.
    booker_tax_code: str | None = None


class PresenceUpdate(PresenceBase):
    # None = unchanged, same admin-only-reassignment semantics as Create.
    student_tax_code: str | None = None
    booker_tax_code: str | None = None
    expected_updated_at: datetime | None = None


class PresenceResponse(PresenceBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    student_tax_code: str
    student: PersonOption
    booker_tax_code: str
    booker: PersonOption
    bookings: list[BookingSummaryResponse]
    created_at: datetime
    updated_at: datetime
