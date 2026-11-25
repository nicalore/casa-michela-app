from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Final
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models.member import Member
from app.models.membership_fee import MembershipFee, MembershipFeeKindEnum
from app.models.student_payment import HoursKindEnum, StudentPaymentKindEnum
from app.models.student_tariff import StudentTariff
from app.services.member_roles import roles_of
from app.services.role_service import RoleService
from app.services.student_payments import (
    PupilBooks,
    days_interleaved,
    pupil_books,
)

_ROME: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_FEE_KINDS: Final[dict[MembershipFeeKindEnum, str]] = {
    MembershipFeeKindEnum.MEMBERSHIP: "MEMBERSHIP_FEE",
    MembershipFeeKindEnum.INSURANCE: "INSURANCE_FEE",
}


@dataclass(frozen=True)
class OwedItem:
    kind: str
    # None while the pupil's initial set-up is still to do.
    cents: int | None
    # Hours: the first and last lesson; fees: the day the fee was recorded.
    first_day: date
    last_day: date
    minutes: int | None = None
    year: int | None = None
    # Hours: every lesson's day, and whether a settled one of the kind falls
    # between them.
    days: tuple[date, ...] = ()
    interleaved: bool = False
    # Every minute comes from the initial set-up.
    opening: bool = False
    fee_id: int | None = None


@dataclass
class Debtor:
    tax_code: str
    first_name: str = ""
    last_name: str = ""
    student: bool = False
    enrolled: bool = False
    roles: tuple[str, ...] = ()
    since: date = date.max
    items: list[OwedItem] = field(default_factory=list)
    opening_pending: bool = False

    @property
    def total_cents(self) -> int:
        return sum(item.cents or 0 for item in self.items)


# The days already settled, by kind of hours.
def _settled_days(book: PupilBooks) -> dict[HoursKindEnum, set[date]]:
    kinds = {
        payment.id: payment.hours_kind or HoursKindEnum.HOURLY
        for payment in book.payments
        if payment.kind == StudentPaymentKindEnum.HOURS
    }
    days: dict[HoursKindEnum, set[date]] = defaultdict(set)

    for item in book.settled:
        if item.payment_id in kinds:
            days[kinds[item.payment_id]].add(item.lesson.day)

    return days


async def debtors(db: AsyncSession, now: datetime) -> list[Debtor]:
    """Every member who owes something today: hours to settle and annual fees."""
    found: dict[str, Debtor] = {}

    def debtor(tax_code: str) -> Debtor:
        return found.setdefault(tax_code, Debtor(tax_code))

    pupils = await db.scalars(select(StudentTariff.student_tax_code).distinct())
    books = await pupil_books(db, list(pupils), now)

    for tax_code, book in books.items():
        status = book.status(now.date())

        if status is None:
            continue

        settled = _settled_days(book)

        for line in status.lines:
            if not line.parts or line.cents <= 0:
                continue

            days = sorted({part.day for part in line.parts})
            owing = debtor(tax_code)
            owing.opening_pending = book.pending
            owing.items.append(
                OwedItem(
                    line.kind,
                    None if book.pending else line.cents,
                    days[0],
                    days[-1],
                    minutes=line.minutes,
                    days=tuple(days),
                    interleaved=days_interleaved(days, settled[line.kind]),
                    opening=all(part.opening for part in line.parts),
                ),
            )
            owing.since = min(owing.since, days[0])

    fees = await db.scalars(
        select(MembershipFee)
        .where(MembershipFee.paid_on.is_(None))
        .order_by(MembershipFee.year, MembershipFee.kind),
    )

    for fee in fees:
        recorded = fee.created_at.astimezone(_ROME).date()
        owing = debtor(fee.member_tax_code)
        owing.items.append(
            OwedItem(
                _FEE_KINDS[fee.kind],
                fee.amount_cents,
                recorded,
                recorded,
                year=fee.year,
                fee_id=fee.id,
            ),
        )
        owing.since = min(owing.since, recorded)

    if not found:
        return []

    members = await db.scalars(
        select(Member)
        .options(joinedload(Member.person), selectinload(Member.memberships))
        .where(Member.tax_code.in_(found)),
    )
    roles = await roles_of(db, list(found))

    for member in members:
        owing = found[member.tax_code]
        owing.first_name = member.person.first_name
        owing.last_name = member.person.last_name
        owing.roles = roles[member.tax_code]
        owing.student = "STUDENTE" in owing.roles
        owing.enrolled = RoleService.is_enrolled(member)

    return sorted(
        found.values(),
        key=lambda row: (row.last_name.casefold(), row.first_name.casefold()),
    )
