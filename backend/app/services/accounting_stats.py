from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, time
from decimal import Decimal
from typing import Final, Literal

from fastapi import HTTPException, status
from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.alphabetical_order import alphabetical_key
from app.models.accounting_opening import TeacherOpening
from app.models.confirmed_hours import ConfirmedBand, ConfirmedHours
from app.models.membership_fee import MembershipFee
from app.models.person import Person
from app.models.staff import CollaborationTypeEnum
from app.models.standard_tariff import StandardTariff
from app.models.student import Student
from app.models.student_hours import StudentConfirmedBand, StudentConfirmedHours
from app.models.student_payment import (
    HoursKindEnum,
    StudentPayment,
    StudentPaymentKindEnum,
)
from app.models.study_program import EducationLevelEnum
from app.services.bilingual import Bilingual
from app.services.compensation import load_terms, months_compensation
from app.services.opening_state import money_from
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

# Places in the ranking of who paid most.
TOP_PAYERS: Final[int] = 10

# Lessons are booked by the quarter hour: a break-even is told in whole quarters.
_QUARTER: Final[int] = 15

_SATURDAY: Final[int] = 5

_LEVEL_ORDER: Final[tuple[EducationLevelEnum, ...]] = (
    EducationLevelEnum.PRIMARY_SCHOOL,
    EducationLevelEnum.MIDDLE_SCHOOL,
    EducationLevelEnum.HIGH_SCHOOL,
)

_FUTURE_YEAR_ERROR: Final[Bilingual] = Bilingual(
    "L'anno non è ancora iniziato",
    "The year hasn't started yet",
)


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


# A pupil's monthly fees in the period against their hours at the cost per hour.
@dataclass(frozen=True)
class FeePupil:
    tax_code: str
    # The latest month's fee.
    fee_cents: int
    months: int
    paid_cents: int
    # Weekend online hours left out: they are paid apart.
    minutes: int
    cost_cents: int
    # Hours a month the fee pays for; None without a cost per hour.
    even_minutes: int | None

    @property
    def margin_cents(self) -> int:
        return self.paid_cents - self.cost_cents


@dataclass(frozen=True)
class FeeBreakEven:
    level: EducationLevelEnum
    fee_cents: int
    minutes: int


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
    # Per hour, from money_from on and without the set-up's pay; None without hours.
    # Lesson income over the pupils' hours, gross pay over the teachers' paid hours,
    # gross pay over the pupils' hours.
    income_per_hour_cents: int | None = None
    pay_per_hour_cents: int | None = None
    lesson_cost_cents: int | None = None
    # Pupil and amount, most first.
    top_payers: list[tuple[str, int]] = field(default_factory=list)
    # Lowest margin first.
    fee_pupils: list[FeePupil] = field(default_factory=list)
    # The standard monthly fees, by level.
    break_even: list[FeeBreakEven] = field(default_factory=list)


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


def _per_hour(cents: int, minutes: int) -> int | None:
    return round(cents * 60 / minutes) if minutes else None


def _even_minutes(fee_cents: int, cost_cents: int) -> int:
    return fee_cents * 60 // cost_cents // _QUARTER * _QUARTER


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
                detail=_FUTURE_YEAR_ERROR.for_request(),
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

    first = await money_from(db)

    # What the per-hour figures read: the app's own accounts, from money_from on.
    def counted(day: date) -> bool:
        return in_period(day) and (first is None or day >= first)

    counted_income = counted_gross = counted_pupil = counted_paid = 0

    payments = await db.scalars(
        select(StudentPayment).where(
            StudentPayment.paid_on >= start,
            StudentPayment.paid_on < end,
        ),
    )
    paid_by: dict[str, int] = defaultdict(int)

    for payment in payments:
        figures = figures_of(payment.paid_on)
        figures.income_cents += payment.amount_cents
        figures.total_income_cents += payment.amount_cents
        figures.income_by_kind[_income_kind(payment)] += payment.amount_cents

        if in_period(payment.paid_on):
            paid_by[payment.student_tax_code] += payment.amount_cents

        if counted(payment.paid_on):
            counted_income += payment.amount_cents

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
                paid_by[member] += cents

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
        minutes = minutes_of(finish) - minutes_of(begin)
        figures_of(day).pupil_minutes += minutes

        if counted(day):
            counted_pupil += minutes

    listed = select(distinct(ConfirmedHours.teacher_tax_code)).where(
        ConfirmedHours.date >= start,
        ConfirmedHours.date < end,
    )

    # Paid only by the initial set-up in its month: no confirmed hours to list them.
    if first is not None and start <= first < end:
        listed = listed.union(
            select(TeacherOpening.tax_code).where(TeacherOpening.gross > 0),
        )

    teachers = await db.scalars(listed)
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

            if not terms.is_paid:
                continue

            figures.paid_minutes += pay.paid_minutes

            # Before the app's accounts, or while the set-up waits: hours, no money.
            if pay.gross is None:
                continue

            figures.gross_cents += _cents(pay.gross)
            figures.net_cents += _cents(pay.net)

            # The set-up's pay stands for days before money_from: out, with them.
            if in_period(month):
                counted_gross += _cents(pay.gross) - _cents(pay.opening_gross)
                counted_paid += sum(
                    day.worked_minutes - day.volunteer_minutes
                    for day in pay.days
                    if counted(day.day)
                )

            if terms.rate is not None:
                figures.volunteer_value_cents += round(
                    pay.volunteer_minutes * _cents(terms.rate) / 60,
                )

    # Fees of months wholly before the app's accounts are left out.
    money_month = None if first is None else first.replace(day=1)
    costed = [
        month
        for month in window
        if in_period(month) and (money_month is None or month >= money_month)
    ]
    lesson_cost = _per_hour(counted_gross, counted_pupil)

    return AccountingStats(
        months=[by_month[month] for month in window],
        period_start=period_start,
        period_end=period_end,
        payers=len(paid_by),
        volunteers=len(volunteers),
        first_year=await _first_year(db, today),
        income_per_hour_cents=_per_hour(counted_income, counted_pupil),
        pay_per_hour_cents=_per_hour(counted_gross, counted_paid),
        lesson_cost_cents=lesson_cost,
        top_payers=await _top_payers(db, paid_by),
        fee_pupils=await _fee_pupils(db, set(costed), lesson_cost),
        break_even=await _break_even(db, lesson_cost),
    )


async def _top_payers(
    db: AsyncSession,
    paid_by: dict[str, int],
) -> list[tuple[str, int]]:
    if not paid_by:
        return []

    names = {
        tax_code: alphabetical_key(last, first)
        for tax_code, first, last in (
            await db.execute(
                select(Person.tax_code, Person.first_name, Person.last_name).where(
                    Person.tax_code.in_(paid_by),
                ),
            )
        ).tuples()
    }
    ranked = sorted(
        paid_by.items(),
        key=lambda item: (-item[1], names.get(item[0], ())),
    )

    return ranked[:TOP_PAYERS]


# Each fee against the hours of the month it pays for, at the period's cost.
async def _fee_pupils(
    db: AsyncSession,
    months: set[date],
    lesson_cost: int | None,
) -> list[FeePupil]:
    # Without a cost per hour every margin would be the whole fee.
    if not months or lesson_cost is None:
        return []

    fees: dict[str, dict[date, int]] = defaultdict(dict)

    for pupil, month, cents in (
        await db.execute(
            select(
                StudentPayment.student_tax_code,
                StudentPayment.month,
                StudentPayment.amount_cents,
            ).where(
                StudentPayment.kind == StudentPaymentKindEnum.MONTH,
                StudentPayment.month.in_(months),
            ),
        )
    ).tuples():
        if month is not None:
            fees[pupil][month] = fees[pupil].get(month, 0) + cents

    if not fees:
        return []

    minutes: dict[str, int] = defaultdict(int)

    for pupil, day, begin, finish, mode in (
        await db.execute(
            select(
                StudentConfirmedHours.student_tax_code,
                StudentConfirmedHours.date,
                StudentConfirmedHours.start_time,
                StudentConfirmedHours.end_time,
                StudentConfirmedHours.mode,
            ).where(
                StudentConfirmedHours.student_tax_code.in_(fees),
                StudentConfirmedHours.date >= min(months),
                StudentConfirmedHours.date < month_after(max(months)),
            ),
        )
    ).tuples():
        if day.replace(day=1) not in fees[pupil]:
            continue

        if mode == "online" and day.weekday() >= _SATURDAY:
            continue

        minutes[pupil] += minutes_of(finish) - minutes_of(begin)

    pupils = [
        FeePupil(
            tax_code=pupil,
            fee_cents=by_month[max(by_month)],
            months=len(by_month),
            paid_cents=sum(by_month.values()),
            minutes=minutes[pupil],
            cost_cents=round(minutes[pupil] * lesson_cost / 60),
            even_minutes=_even_minutes(by_month[max(by_month)], lesson_cost),
        )
        for pupil, by_month in fees.items()
    ]
    names = {
        tax_code: alphabetical_key(last, first)
        for tax_code, first, last in (
            await db.execute(
                select(Person.tax_code, Person.first_name, Person.last_name).where(
                    Person.tax_code.in_(fees),
                ),
            )
        ).tuples()
    }

    return sorted(
        pupils,
        key=lambda pupil: (pupil.margin_cents, names.get(pupil.tax_code, ())),
    )


async def _break_even(
    db: AsyncSession,
    lesson_cost: int | None,
) -> list[FeeBreakEven]:
    if lesson_cost is None:
        return []

    tariffs = {
        tariff.level: tariff.monthly_cents
        for tariff in await db.scalars(select(StandardTariff))
        if tariff.monthly_enabled and tariff.monthly_cents
    }

    return [
        FeeBreakEven(level, cents, _even_minutes(cents, lesson_cost))
        for level in _LEVEL_ORDER
        if (cents := tariffs.get(level))
    ]

