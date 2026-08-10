from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption


class CalendarPublicationCreate(BaseModel):
    date: date
    band: TimeBandEnum


class CalendarPublicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum
    published_at: datetime

    # Null once the administrator who published is no longer one: the fact
    # outlives the person, even where the name does not.
    published_by: str | None = None
    publisher: PersonOption | None = None

    # Rooms found over capacity while publishing. Said and not enforced.
    warnings: list[str] = Field(default_factory=list)
