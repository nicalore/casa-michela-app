from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core import field_lengths
from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption
from app.schemas.validators import OptionalCleanStr


class CalendarTeacherNoteEntry(BaseModel):
    teacher_tax_code: str

    # Blank means no note for this teacher.
    text: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)


# The band's whole set: teachers left out lose their note.
class CalendarTeacherNotesReplace(BaseModel):
    date: date

    band: TimeBandEnum

    notes: list[CalendarTeacherNoteEntry]


class CalendarTeacherNoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum

    teacher_tax_code: str

    text: str

    author: PersonOption | None = None

    updated_at: datetime
