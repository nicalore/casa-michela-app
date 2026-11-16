from datetime import date, time
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.teacher_hours import HoursSpan


class StudentSituationResponse(BaseModel):
    kind: Literal[
        "NONE",
        "PACKAGE_LEFT",
        "PACKAGE_ENDED",
        "MONTH_PAID",
        "MONTH_UNPAID",
        "SETTLE",
        "AHEAD_LEFT",
        "AHEAD_ENDED",
    ]
    tariff_kind: Literal["HOURLY", "PACKAGE", "MONTHLY"] | None
    # By the hour, the package or the month, as the tariff is paid.
    tariff_cents: int | None
    package_hours: int | None
    # Left of the package or hours paid ahead; once run out, those not covered.
    minutes: int
    # The package running from this band is a renewal already paid.
    renewed: bool
    # What this band's hours add to what is left to settle.
    cost_cents: int


class StudentHoursRowResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    mode: str
    absent: bool
    # Not in the calendar: an admin added it.
    added: bool
    # The calendar's hours; null for a row added by hand.
    planned: list[HoursSpan] | None
    work: list[HoursSpan]
    minutes: int
    situation: StudentSituationResponse


class StudentHoursBandResponse(BaseModel):
    date: date
    band: str
    status: Literal["EMPTY", "WAITING", "LIVE", "READY", "CONFIRMED"]
    rows: list[StudentHoursRowResponse]
    waiting: list[str]
    waiting_tax_codes: list[str]
    first_end: time | None
    last_end: time | None
    next_arrival: time | None
    reopened: bool


# Only the fields sent change.
class StudentHoursRowUpdate(BaseModel):
    work: list[HoursSpan] | None = Field(None, min_length=1)
    absent: bool | None = None


class StudentHoursRowCreate(BaseModel):
    tax_code: str = Field(..., min_length=16, max_length=16)
    mode: Literal["presence", "online"]
    work: list[HoursSpan] = Field(..., min_length=1)
