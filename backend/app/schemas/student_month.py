from datetime import date

from pydantic import BaseModel

from app.schemas.teacher_month import PendingBandResponse


class StudentStandingResponse(BaseModel):
    # PACKAGE_LEFT, PACKAGE_ENDED, MONTH_PAID, MONTH_UNPAID, SETTLE, SETTLED,
    # AHEAD_LEFT, AHEAD_ENDED, PENDING (initial set-up to do) or NONE.
    kind: str
    minutes: int
    due_cents: int
    renewal: bool


class TariffPartResponse(BaseModel):
    # HOURLY, PACKAGE or MONTHLY; null for lessons before any tariff.
    tariff_kind: str | None
    amount_cents: int | None
    package_hours: int | None
    # Only when it took over after the month's first day, or ended before its last.
    starts_on: date | None
    ends_on: date | None
    days: int
    presence_days: int
    online_days: int
    minutes: int
    presence_minutes: int
    online_minutes: int


class StudentMonthRowResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    parts: list[TariffPartResponse]
    # Null once a later month has a day confirmed.
    situation: StudentStandingResponse | None


class StudentMonthResponse(BaseModel):
    month: date
    rows: list[StudentMonthRowResponse]
    pending: list[PendingBandResponse]
    finished: bool
    # The month's last day once it is over or past; null for today's situations.
    situation_on: date | None
    # False once a day of a later month is confirmed: the situations are read there.
    situation_shown: bool
