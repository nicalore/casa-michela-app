from datetime import date, datetime

from pydantic import ConfigDict

from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.schemas.validators import QuarterHourTimeRangeMixin, TimeBandMixin


class RoomSupervisionBase(TimeBandMixin):
    date: date
    teacher_tax_code: str
    room_id: int


class RoomSupervisionCreate(RoomSupervisionBase):
    pass


class RoomSupervisionUpdate(TimeBandMixin):
    expected_updated_at: datetime | None = None


# Shorter than a band: a room may hold a single 15-minute lesson.
class RoomSupervisionResponse(QuarterHourTimeRangeMixin):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date
    teacher_tax_code: str
    teacher: PersonOption
    room: RoomOption
    created_at: datetime
    updated_at: datetime
