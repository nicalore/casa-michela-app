from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, time
from decimal import Decimal
from typing import Final, Literal

from fastapi import HTTPException, status
from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.confirmed_hours import ConfirmedBand, ConfirmedHours
from app.models.membership_fee import MembershipFee
from app.models.staff import CollaborationTypeEnum
from app.models.student import Student
from app.models.student_hours import StudentConfirmedBand, StudentConfirmedHours
from app.models.student_payment import (
    HoursKindEnum,
    StudentPayment,
    StudentPaymentKindEnum,
)
from app.services.compensation import load_terms, months_compensation
from app.services.worked_hours import minutes_of, month_after

# How the money came in, as the statistics group it; FEES: the annual membership
# and insurance fees together, of every member.
IncomeKind = Literal["PACKAGE", "MONTH", "HOURLY", "AHEAD", "WEEKEND_ONLINE", "FEES"]

INCOME_KINDS: Final[tuple[IncomeKind, ...]] = (
    "PACKAGE",
    "MONTH",
    "HOURLY",
    "AHEAD",
    "WEEKEND_ONLINE",
    "FEES",
)

# The chart always shows a year's worth of months.
WINDOW_MONTHS: Final[int] = 12

_FUTURE_YEAR_ERROR: Final[str] = "L'anno non è ancora iniziato"


@dataclass
class MonthFigures:
    month: date
    # From the pupils: their payments and their own annual fees.
    income_cents: int = 0
    # From everybody: the pupils' and the annual fees of the other members.
    total_income_cents: int = 0
    income_by_kind: dict[IncomeKind, int] = field(
        default_factory=lambda: dict.fromkeys(INCOME_KINDS, 0),
    )
    gross_cents: int = 0
    net_cents: int = 0
    # Hours the pupils had, and the hours paid to the teachers.
    pupil_minutes: int = 0
    paid_minutes: int = 0
    volunteer_minutes: int = 0
    # Volunteering at each paid teacher's own hourly rate; volunteers are left out.
    volunteer_value_cents: int = 0


@dataclass(frozen=True)
class AccountingStats:
    months: list[MonthFigures]
    # The months the figures add up, first and last, within the window.
    period_start: date
    period_end: date
    # Pupils who paid, teachers who gave volunteering, within the period.
    payers: int
    volunteers: int
    # The first year with anything in it, for the choice of years.
    first_year: int


def _months_from(first: date, count: int) -> list[date]:
    months = [first]

    while len(months) < count:
        months.append(month_after(months[-1]))

    return months


def _shift(month: date, back: int) -> date:
    index = month.year * 12 + month.month - 1 - back

    return date(index // 12, index % 12 + 1, 1)


def _cents(amount: Decimal | None) -> int:
    return 0 if amount is None else int((amount * 100).to_integral_value())


def _income_kind(payment: StudentPayment) -> IncomeKind:
    if payment.kind == StudentPaymentKindEnum.PACKAGE:
        return "PACKAGE"

    if payment.kind == StudentPaymentKindEnum.MONTH:
        return "MONTH"

    if payment.kind == StudentPaymentKindEnum.AHEAD:
        return "AHEAD"

    if payment.hours_kind == HoursKindEnum.WEEKEND_ONLINE:
        return "WEEKEND_ONLINE"

    return "HOURLY"


# Last months: the twelve up to this one. A year: January to December.
def _window(
    today: date,
    months: int | None,
    year: int | None,
) -> tuple[list[date], date, date]:
    this_month = today.replace(day=1)

    if year is not None:
        if year > today.year:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_FUTURE_YEAR_ERROR,
            )

        window = _months_from(date(year, 1, 1), WINDOW_MONTHS)

        return window, window[0], min(window[-1], this_month)

    count = months or WINDOW_MONTHS
    window = _months_from(_shift(this_month, WINDOW_MONTHS - 1), WINDOW_MONTHS)

    return window, _shift(this_month, count - 1), this_month


async def _first_year(db: AsyncSession, today: date) -> int:
    firsts = [
        await db.scalar(select(func.min(StudentPayment.paid_on))),
        await db.scalar(select(func.min(MembershipFee.paid_on))),
        await db.scalar(select(func.min(ConfirmedBand.date))),
        await db.scalar(select(func.min(StudentConfirmedBand.date))),
    ]
    known = [day for day in firsts if day is not None]

    return min(known).year if known else today.year


async def accounting_stats(
    db: AsyncSession,
    now: datetime,
    is_over: Callable[[date, time], bool],
    *,
    months: int | None = None,
    year: int | None = None,
) -> AccountingStats:
    today = now.date()
    window, period_start, period_end = _window(today, months, year)
    start, end = window[0], month_after(window[-1])
    by_month = {month: MonthFigures(month) for month in window}

    def figures_of(day: date) -> MonthFigures:
        return by_month[day.replace(day=1)]

    def in_period(day: date) -> bool:
        return period_start <= day.replace(day=1) <= period_end

    payments = await db.scalars(
        select(StudentPayment).where(
            StudentPayment.paid_on >= start,
            StudentPayment.paid_on < end,
        ),
    )
    payers: set[str] = set()

    for payment in payments:
        figures = figures_of(payment.paid_on)
        figures.income_cents += payment.amount_cents
        figures.total_income_cents += payment.amount_cents
        figures.income_by_kind[_income_kind(payment)] += payment.amount_cents

        if in_period(payment.paid_on):
            payers.add(payment.student_tax_code)

    fees = await db.execute(
        select(
            MembershipFee.member_tax_code,
            MembershipFee.paid_on,
            MembershipFee.amount_cents,
            Student.tax_code,
        )
        .outerjoin(Student, Student.tax_code == MembershipFee.member_tax_code)
        .where(MembershipFee.paid_on >= start, MembershipFee.paid_on < end),
    )

    for member, paid_on, cents, pupil in fees.tuples():
        figures = figures_of(paid_on)
        figures.total_income_cents += cents
        figures.income_by_kind["FEES"] += cents

        if pupil is not None:
            figures.income_cents += cents

            if in_period(paid_on):
                payers.add(member)

    hours = await db.execute(
        select(
            StudentConfirmedHours.date,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
        ).where(
            StudentConfirmedHours.date >= start,
            StudentConfirmedHours.date < end,
        ),
    )

    for day, begin, finish in hours.tuples():
        figures_of(day).pupil_minutes += minutes_of(finish) - minutes_of(begin)

    teachers = await db.scalars(
        select(distinct(ConfirmedHours.teacher_tax_code)).where(
            ConfirmedHours.date >= start,
            ConfirmedHours.date < end,
        ),
    )
    volunteers: set[str] = set()

    for tax_code in list(teachers):
        timeline = await load_terms(db, tax_code)
        paid = await months_compensation(db, tax_code, window, is_over, timeline)

        for month, pay in zip(window, paid, strict=True):
            figures = by_month[month]
            terms = pay.terms

            # A volunteer gives every hour; other unpaid kinds give none.
            if terms.collaboration_type == CollaborationTypeEnum.VOLUNTEER:
                given = pay.worked_minutes
            else:
                given = pay.volunteer_minutes if terms.is_paid else 0

            figures.volunteer_minutes += given

            if given and in_period(month):
                volunteers.add(tax_code)

            if not terms.is_paid or pay.gross is None:
                continue

            figures.gross_cents += _cents(pay.gross)
            figures.net_cents += _cents(pay.net)
            figures.paid_minutes += pay.paid_minutes

            if terms.rate is not None:
                figures.volunteer_value_cents += round(
                    pay.volunteer_minutes * _cents(terms.rate) / 60,
                )

    return AccountingStats(
        months=[by_month[month] for month in window],
        period_start=period_start,
        period_end=period_end,
        payers=len(payers),
        volunteers=len(volunteers),
        first_year=await _first_year(db, today),
    )

