from datetime import date, time
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class HoursSpan(BaseModel):
    start_time: time
    end_time: time


class TeacherHoursRowResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    mode: str
    collaboration_type: str
    absent: bool
    # Not in the calendar: an admin added it.
    added: bool
    # The calendar's hours; null for a row added by hand.
    planned: list[HoursSpan] | None
    work: list[HoursSpan]
    volunteer: HoursSpan | None
    # What the weekly hour would give here, whatever was set.
    volunteer_proposed: HoursSpan | None
    volunteer_set: bool
    worked_minutes: int
    volunteer_minutes: int
    gross: Decimal | None
    net: Decimal | None


class TeacherHoursBandResponse(BaseModel):
    date: date
    band: str
    status: Literal["EMPTY", "WAITING", "LIVE", "READY", "CONFIRMED"]
    rows: list[TeacherHoursRowResponse]
    waiting: list[str]
    waiting_tax_codes: list[str]
    first_end: time | None
    last_end: time | None
    next_arrival: time | None
    reopened: bool


# Only the fields sent change; a null volunteer means none at all.
class TeacherHoursRowUpdate(BaseModel):
    work: list[HoursSpan] | None = Field(None, min_length=1)
    volunteer: HoursSpan | None = None
    absent: bool | None = None


class TeacherHoursRowCreate(BaseModel):
    tax_code: str = Field(..., min_length=16, max_length=16)
    mode: Literal["presence", "online"]
    work: list[HoursSpan] = Field(..., min_length=1)
    # Left out, the weekly hour decides.
    volunteer: HoursSpan | None = None


class VolunteerProposalResponse(BaseModel):
    volunteer: HoursSpan | None
