from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption


class CalendarPublicationCreate(BaseModel):
    date: date
    band: TimeBandEnum


class CalendarDraftClosed(BaseModel):
    publication: "CalendarPublicationResponse"

    resent: bool


# Leaving a bozza without publishing answers one thing worth saying out loud.
class CalendarDraftDiscarded(BaseModel):
    publication: "CalendarPublicationResponse"

    # Hours the snapshot could not put back, because what they stood on is gone:
    # an availability withdrawn, a request cancelled. Zero on an ordinary undo.
    lost: int


class CalendarPublicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum
    published_at: datetime

    published_by: str | None = None
    publisher: PersonOption | None = None

    is_draft: bool = False

    # Whose bozza it is. Only they can leave it without publishing, so the
    # screen can say so instead of offering a button that would be refused.
    draft_opened_by: str | None = None
    draft_opener: PersonOption | None = None

    has_changes: bool = False

    warnings: list[str] = Field(default_factory=list)
