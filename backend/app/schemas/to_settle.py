from datetime import date
from typing import Literal

from pydantic import BaseModel

from app.schemas.member_roles import MemberRole


class OwedItemResponse(BaseModel):
    # Hours to settle by their line, or an annual fee.
    kind: Literal[
        "HOURLY",
        "OVER_PACKAGE",
        "OVER_FEE",
        "WEEKEND_ONLINE",
        "MEMBERSHIP_FEE",
        "INSURANCE_FEE",
    ]
    # Null while the pupil's initial set-up is still to do.
    cents: int | None
    # Hours only.
    minutes: int | None
    # Fees only: the membership year.
    year: int | None
    # Hours: the first and last lesson; fees: the day the fee was recorded.
    first_day: date
    last_day: date
    # Hours: every lesson's day; a settled one of the kind between them makes
    # the row name its days rather than a span.
    days: list[date] = []
    interleaved: bool = False
    # Every minute comes from the initial set-up.
    opening: bool = False
    # Fees only.
    fee_id: int | None = None


class DebtorResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str
    student: bool
    enrolled: bool
    # Every role the person holds, for the filter.
    roles: list[MemberRole]
    # The oldest lesson still to settle, or the day an owed fee was recorded.
    since: date
    total_cents: int
    items: list[OwedItemResponse]
    # The pupil's initial set-up is still to do: hours have no amount yet.
    opening_pending: bool = False


class ToSettleResponse(BaseModel):
    total_cents: int
    # By surname.
    rows: list[DebtorResponse]
