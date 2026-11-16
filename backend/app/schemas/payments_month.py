from datetime import date
from typing import Literal

from pydantic import BaseModel

from app.schemas.member_roles import MemberRole


class MonthPaymentResponse(BaseModel):
    paid_on: date
    tax_code: str
    first_name: str
    last_name: str
    # Every role the payer holds, for the filter.
    roles: list[MemberRole]
    kind: Literal[
        "PACKAGE",
        "MONTH",
        "AHEAD",
        "HOURLY",
        "OVER_PACKAGE",
        "OVER_FEE",
        "WEEKEND_ONLINE",
        "MEMBERSHIP_FEE",
        "INSURANCE_FEE",
    ]
    amount_cents: int
    payment_method: str | None
    payment_method_other: str | None
    package_hours: int | None
    # A month's fee; null while it waits for a package to end.
    month: date | None
    ahead_minutes: int | None
    # Hours settled.
    minutes: int | None
    # Annual fees: the membership year.
    year: int | None


class PaymentsMonthResponse(BaseModel):
    month: date
    total_cents: int
    # Newest first.
    rows: list[MonthPaymentResponse]
