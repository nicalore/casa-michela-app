from datetime import date

from pydantic import BaseModel


class AccountingMonthResponse(BaseModel):
    month: date
    # From the pupils, their own annual fees included.
    income_cents: int
    # From everybody: the other members' annual fees too.
    total_income_cents: int
    # PACKAGE, MONTH, HOURLY, AHEAD, WEEKEND_ONLINE, FEES; they add up to the total.
    income_by_kind: dict[str, int]
    gross_cents: int
    net_cents: int
    pupil_minutes: int
    paid_minutes: int
    volunteer_minutes: int
    volunteer_value_cents: int


class AccountingStatsResponse(BaseModel):
    # Twelve months: the last ones up to this, or a year from January.
    months: list[AccountingMonthResponse]
    # First months of the first and the last month the figures add up.
    period_start: date
    period_end: date
    payers: int
    volunteers: int
    first_year: int
