from datetime import date

from pydantic import BaseModel

from app.schemas.person import PersonOption


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


class PayerItem(BaseModel):
    person: PersonOption
    cents: int


# Fees of the period's months against the hours they covered.
class FeePupilItem(BaseModel):
    person: PersonOption
    # The latest month's fee.
    fee_cents: int
    months: int
    paid_cents: int
    # Weekend online hours left out: they are paid apart.
    minutes: int
    cost_cents: int
    # Hours a month the fee pays for, in whole quarters.
    even_minutes: int | None


class FeeBreakEvenItem(BaseModel):
    level: str
    fee_cents: int
    minutes: int


class AccountingStatsResponse(BaseModel):
    # Twelve months: the last ones up to this, or a year from January.
    months: list[AccountingMonthResponse]
    # First months of the first and the last month the figures add up.
    period_start: date
    period_end: date
    payers: int
    volunteers: int
    first_year: int
    # Per hour from money_from on, the set-up's pay left out; None without hours.
    # Lesson income per pupil hour, gross pay per teacher's paid hour, gross pay
    # per pupil hour.
    income_per_hour_cents: int | None
    pay_per_hour_cents: int | None
    lesson_cost_cents: int | None
    top_payers: list[PayerItem]
    # Lowest margin first.
    fee_pupils: list[FeePupilItem]
    # The standard monthly fee of each level.
    break_even: list[FeeBreakEvenItem]
