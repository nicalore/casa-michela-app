from datetime import date, time
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

VolunteeringRuleName = Literal["weekly", "daily", "none"]


# A paid teacher's unpaid hour and pay under one rule.
class RuleFiguresResponse(BaseModel):
    volunteer_minutes: int
    paid_minutes: int
    gross: Decimal | None
    net: Decimal | None


class CompensationSpanResponse(BaseModel):
    start_time: time
    end_time: time
    mode: Literal["presence", "online"] = "presence"


class CompensationDayResponse(BaseModel):
    date: date
    worked: list[CompensationSpanResponse]
    volunteer: list[CompensationSpanResponse]
    worked_minutes: int
    volunteer_minutes: int
    gross: Decimal | None
    net: Decimal | None


class CompensationMonthResponse(BaseModel):
    collaboration_type: str

    # Null unless paid, and without a rate nobody entered yet.
    gross_rate: Decimal | None
    net_rate: Decimal | None
    gross: Decimal | None
    net: Decimal | None

    worked_minutes: int
    volunteer_minutes: int
    paid_minutes: int
    days: list[CompensationDayResponse]

    # Not for those whose admin role forbids being paid.
    can_edit: bool

    # How the month counts the unpaid hour; month_only when the monthly summary
    # chose it for this month alone, against the teacher's rule.
    volunteering: VolunteeringRuleName
    volunteering_month_only: bool
    # Months with their own choice that a rule from this month would replace.
    volunteering_replaced: list[date]

    # The month under each rule, were it the teacher's from here: null unless paid.
    volunteering_previews: dict[VolunteeringRuleName, RuleFiguresResponse] | None


class IbanUpdate(BaseModel):
    # Null removes it.
    iban: str | None = Field(..., pattern=r"^IT[0-9]{2}[A-Z][0-9]{10}[A-Z0-9]{12}$")


class CompensationUpdate(BaseModel):
    year: int = Field(..., ge=2000, le=2100)
    month: int = Field(..., ge=1, le=12)
    collaboration_type: Literal["VOLUNTEER", "PAID", "PCTO"]
    gross_compensation: Decimal | None = Field(
        None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )


class VolunteeringRuleChangeUpdate(BaseModel):
    year: int = Field(..., ge=2000, le=2100)
    month: int = Field(..., ge=1, le=12)
    rule: VolunteeringRuleName
