from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel

from app.schemas.compensation import RuleFiguresResponse, VolunteeringRuleName


class PaymentReceiptResponse(BaseModel):
    file_name: str
    content_type: str
    size: int
    uploaded_at: datetime


class TeacherMonthRowResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    collaboration_type: str
    days: int
    presence_days: int
    online_days: int
    worked_minutes: int
    volunteer_minutes: int
    # Null where nothing is paid.
    paid_minutes: int | None
    gross: Decimal | None
    net: Decimal | None
    availabilities: int
    below_monthly: bool
    short_weeks: int
    # How this month counts the unpaid hour, and what the teacher's Compensi say.
    volunteering: VolunteeringRuleName
    standing_volunteering: VolunteeringRuleName
    # Under each rule for this month alone: what a switch picked and not saved gives.
    rule_figures: dict[VolunteeringRuleName, RuleFiguresResponse] | None
    # The bank transfer receipt of the month, without its bytes.
    receipt: PaymentReceiptResponse | None
    # Its initial set-up is still to do: no money yet.
    opening_pending: bool = False


class PendingBandResponse(BaseModel):
    date: date
    band: str


class TeacherMonthResponse(BaseModel):
    month: date
    rows: list[TeacherMonthRowResponse]
    pending: list[PendingBandResponse]
    finished: bool


class VolunteeringRuleUpdate(BaseModel):
    rule: VolunteeringRuleName
