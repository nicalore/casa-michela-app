from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption


class CalendarLockResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum

    holder_tax_code: str

    holder: PersonOption | None = None

    # Heartbeats move expires_at, not this.
    acquired_at: datetime

    expires_at: datetime


class CalendarLockState(BaseModel):
    lock: CalendarLockResponse | None = None

    # False with a lock present means somebody else holds it.
    mine: bool = False
