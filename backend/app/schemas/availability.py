from datetime import date, datetime

from pydantic import ConfigDict

from app.schemas.opening_day import OpeningModeEnum
from app.schemas.person import PersonOption
from app.schemas.validators import QuarterHourTimeRangeMixin


class AvailabilityBase(QuarterHourTimeRangeMixin):
    date: date

    # Offered against exactly one of the two opening-hour modes.
    mode: OpeningModeEnum


class AvailabilityCreate(AvailabilityBase):
    # Admin-only: a non-admin caller's value is ignored server-side in favor
    # of their own tax code.
    teacher_tax_code: str | None = None


class AvailabilityUpdate(AvailabilityBase):
    teacher_tax_code: str | None = None
    expected_updated_at: datetime | None = None


class AvailabilityResponse(AvailabilityBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    teacher_tax_code: str
    teacher: PersonOption
    created_at: datetime
    updated_at: datetime
