from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption


class CalendarLockResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum

    holder_tax_code: str

    # Named and not just identified: the banner the others read says who, and a
    # tax code is not something to show anybody.
    holder: PersonOption | None = None

    # When they started, which is the hour the banner says. The beat moves the
    # deadline and leaves this where it is.
    acquired_at: datetime

    # When the band comes free if nothing else is heard from them. The client
    # shows it so that waiting is a wait and not a guess.
    expires_at: datetime


# What the heartbeat answers: the lock as it stands now, or nothing at all where
# the band has been taken by somebody else in the meantime — which is how a
# client that has lost it finds out.
class CalendarLockState(BaseModel):
    lock: CalendarLockResponse | None = None

    # Whether the band is still the caller's. False with a lock present means
    # somebody else has it now.
    mine: bool = False
