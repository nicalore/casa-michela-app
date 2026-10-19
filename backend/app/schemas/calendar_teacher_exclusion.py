from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.core.time_band import TimeBandEnum
from app.schemas.person import PersonOption


class CalendarTeacherExclusionCreate(BaseModel):
    date: date

    band: TimeBandEnum

    teacher_tax_code: str


class CalendarTeacherExclusionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    band: TimeBandEnum

    teacher_tax_code: str
    teacher: PersonOption | None = None

    # Lessons sent back to the panel by this write; always zero on reads.
    unplanned_lessons: int = 0

    unassigned_activities: int = 0

    created_at: datetime
