from collections import defaultdict
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field, replace
from datetime import date, time, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.compensation_term import CompensationTerm
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.volunteering import (
    VolunteeringMonth,
    VolunteeringRule,
    VolunteeringRuleChange,
)
from app.services.confirmed_hours import confirmed_bands, confirmed_work
from app.services.worked_hours import (
    BEGINNING,
    MINUTES_PER_HOUR,
    BandWork,
    Span,
    band_work,
    days_of,
    merge,
    month_after,
    span_minutes,
    teacher_rows,
)

WEEKLY_VOLUNTEER_MINUTES: Final[int] = MINUTES_PER_HOUR
DAILY_VOLUNTEER_MINUTES: Final[int] = MINUTES_PER_HOUR

_CENTS: Final[Decimal] = Decimal("0.01")
_ZERO: Final[Decimal] = Decimal("0.00")


@dataclass(frozen=True)
class Terms:
    collaboration_type: CollaborationTypeEnum
    gross_compensation: Decimal | None

    @property
    def is_paid(self) -> bool:
        return self.collaboration_type == CollaborationTypeEnum.PAID

    # Only a paid collaboration has a rate, whatever was left behind.
    @property
    def rate(self) -> Decimal | None:
        return self.gross_compensation if self.is_paid else None


@dataclass(frozen=True)
class TermsTimeline:
    current: Terms
    changes: Sequence[CompensationTerm]
    # The teacher's rule from each month on, oldest first; before any, one a week.
    rules: Sequence[tuple[date, VolunteeringRule]] = ()
    # Months counted otherwise, chosen in the monthly summary for that month alone.
    month_rules: Mapping[date, VolunteeringRule] = field(default_factory=dict)

    def of_month(self, month: date) -> Terms:
        latest = None

        for change in self.changes:
            if change.starts_on <= month:
                latest = change

        if latest is None:
            return self.current

        return Terms(latest.collaboration_type, latest.gross_compensation)

    # Whether a day's work owes the weekly hour: only paid months do.
    def counts(self, day: date) -> bool:
        return self.of_month(day.replace(day=1)).is_paid

    # What the teacher's Compensi say for the month.
    def standing_rule(self, month: date) -> VolunteeringRule:
        latest = VolunteeringRule.WEEKLY

        for starts_on, rule in self.rules:
            if starts_on <= month:
                latest = rule

        return latest

    # Months with their own choice that a rule from this month would replace.
    def chosen_from(self, month: date) -> list[date]:
        until = next(
            (starts_on for starts_on, _ in self.rules if starts_on > month),
            None,
        )

        return sorted(
            chosen
            for chosen in self.month_rules
            if month <= chosen and (until is None or chosen < until)
        )

    # What the day's month counts: its own choice, else the teacher's rule.
    def rule(self, day: date) -> VolunteeringRule:
        month = day.replace(day=1)

        return self.month_rules.get(month) or self.standing_rule(month)


@dataclass(frozen=True)
class CompensationDay:
    day: date
    worked: list[Span]
    volunteer: list[Span]
    gross: Decimal | None
    net: Decimal | None
    # The day's online hours, so each worked stretch can say its mode.
    online: list[Span] = field(default_factory=list)

    def is_online(self, span: Span) -> bool:
        start, end = span

        return any(
            first <= start and end <= last for first, last in self.online
        )

    @property
    def worked_minutes(self) -> int:
        return span_minutes(self.worked)

    @property
    def volunteer_minutes(self) -> int:
        return span_minutes(self.volunteer)


@dataclass(frozen=True)
class CompensationMonth:
    terms: Terms
    days: list[CompensationDay]
    gross: Decimal | None
    net: Decimal | None

    @property
    def worked_minutes(self) -> int:
        return sum(day.worked_minutes for day in self.days)

    @property
    def volunteer_minutes(self) -> int:
        return sum(day.volunteer_minutes for day in self.days)

    @property
    def paid_minutes(self) -> int:
        return self.worked_minutes - self.volunteer_minutes


def monday_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


def amount(minutes: int, rate: Decimal) -> Decimal:
    return (Decimal(minutes) / MINUTES_PER_HOUR * rate).quantize(
        _CENTS,
        rounding=ROUND_HALF_UP,
    )


# A fifth off, as the app shows it.
def net_of(gross: Decimal) -> Decimal:
    return (gross * 4 / 5).quantize(_CENTS, rounding=ROUND_HALF_UP)


def _weekly(_day: date) -> VolunteeringRule:
    return VolunteeringRule.WEEKLY


# The first hour worked in person each week, wherever it falls: a short first
# band goes on into the next, online never gives any. In a month counted by the
# day it is the first hour of each day instead, and a short day gives what it has;
# in a month counted as none, no hour is owed. A band written by hand gives what
# it says, whatever the rule, and what it leaves of the hour moves on the same way.
# A week that never reaches the hour gives what it has.
def allot_volunteering(
    bands: Sequence[BandWork],
    counts: Callable[[date], bool],
    rule: Callable[[date], VolunteeringRule] = _weekly,
) -> dict[tuple[date, str], list[Span]]:
    owed_week: dict[date, int] = defaultdict(lambda: WEEKLY_VOLUNTEER_MINUTES)
    owed_day: dict[date, int] = defaultdict(lambda: DAILY_VOLUNTEER_MINUTES)
    allotted: dict[tuple[date, str], list[Span]] = {}

    def give(day: date, minutes: int) -> None:
        week = monday_of(day)
        owed_week[week] = max(0, owed_week[week] - minutes)
        owed_day[day] = max(0, owed_day[day] - minutes)

    for work in sorted(bands, key=lambda work: work.key):
        if not counts(work.day):
            continue

        if work.volunteer is not None:
            if work.volunteer:
                allotted[(work.day, work.band)] = list(work.volunteer)

            give(work.day, span_minutes(work.volunteer))

            continue

        kind = rule(work.day)

        if not work.presence or kind == VolunteeringRule.NONE:
            continue

        daily = kind == VolunteeringRule.DAILY
        owed = owed_day if daily else owed_week
        key = work.day if daily else monday_of(work.day)

        for start, end in work.spans:
            given = min(owed[key], end - start)

            if given == 0:
                break

            allotted.setdefault((work.day, work.band), []).append(
                (start, start + given),
            )
            give(work.day, given)

    return allotted


def volunteer_by_day(
    allotted: Mapping[tuple[date, str], list[Span]],
) -> dict[date, list[Span]]:
    by_day: dict[date, list[Span]] = defaultdict(list)

    for (day, _), spans in sorted(allotted.items()):
        by_day[day].extend(spans)

    return {day: sorted(spans) for day, spans in by_day.items()}


async def load_terms(db: AsyncSession, tax_code: str) -> TermsTimeline:
    staff = await db.scalar(select(Staff).where(Staff.tax_code == tax_code))

    # Staff is required for every teacher; nothing paid is the safe reading anyway.
    if staff is None:
        return TermsTimeline(Terms(CollaborationTypeEnum.UNPAID, None), [])

    changes = await db.scalars(
        select(CompensationTerm)
        .where(CompensationTerm.staff_tax_code == tax_code)
        .order_by(CompensationTerm.starts_on),
    )

    rules = await db.execute(
        select(VolunteeringRuleChange.starts_on, VolunteeringRuleChange.rule)
        .where(VolunteeringRuleChange.staff_tax_code == tax_code)
        .order_by(VolunteeringRuleChange.starts_on),
    )
    months = await db.execute(
        select(VolunteeringMonth.month, VolunteeringMonth.rule).where(
            VolunteeringMonth.teacher_tax_code == tax_code,
        ),
    )

    return TermsTimeline(
        Terms(staff.collaboration_type, staff.gross_compensation),
        changes.all(),
        [(starts_on, VolunteeringRule(rule)) for starts_on, rule in rules.tuples()],
        {month: VolunteeringRule(rule) for month, rule in months.tuples()},
    )


# The teacher's rule from this month on, until their next change, which stays.
# A month chosen alone in the monthly summary within that stretch follows it now.
# Gives what the month counted before, or None when no month counts otherwise.
async def set_volunteering_rule(
    db: AsyncSession,
    tax_code: str,
    month: date,
    rule: VolunteeringRule,
) -> VolunteeringRule | None:
    timeline = await load_terms(db, tax_code)
    changes = list(
        await db.scalars(
            select(VolunteeringRuleChange)
            .where(VolunteeringRuleChange.staff_tax_code == tax_code)
            .order_by(VolunteeringRuleChange.starts_on),
        ),
    )
    until = next(
        (change.starts_on for change in changes if change.starts_on > month),
        None,
    )
    chosen = list(
        await db.scalars(
            select(VolunteeringMonth).where(
                VolunteeringMonth.teacher_tax_code == tax_code,
                VolunteeringMonth.month >= month,
                *([VolunteeringMonth.month < until] if until is not None else []),
            ),
        ),
    )
    changed = timeline.standing_rule(month) != rule or any(
        row.rule != rule for row in chosen
    )

    for row in chosen:
        await db.delete(row)

    # A row only where the rule turns: the months before already say this one.
    earlier = VolunteeringRule.WEEKLY

    for change in changes:
        if change.starts_on < month:
            earlier = VolunteeringRule(change.rule)

    row = next((change for change in changes if change.starts_on == month), None)

    if rule == earlier:
        if row is not None:
            await db.delete(row)
    elif row is None:
        db.add(
            VolunteeringRuleChange(
                staff_tax_code=tax_code,
                starts_on=month,
                rule=rule.value,
            ),
        )
    else:
        row.rule = rule.value

    await db.flush()

    return timeline.rule(month) if changed else None


# Holds until the next change, which stays. Staff always says the latest.
async def set_terms(
    db: AsyncSession,
    staff: Staff,
    month: date,
    collaboration_type: CollaborationTypeEnum,
    gross_compensation: Decimal | None,
) -> None:
    changes = list(
        await db.scalars(
            select(CompensationTerm)
            .where(CompensationTerm.staff_tax_code == staff.tax_code)
            .order_by(CompensationTerm.starts_on),
        ),
    )

    # The months before this first change keep what Staff said until now.
    if not changes:
        changes.append(
            CompensationTerm(
                staff_tax_code=staff.tax_code,
                starts_on=BEGINNING,
                collaboration_type=staff.collaboration_type,
                gross_compensation=staff.gross_compensation,
            ),
        )
        db.add(changes[0])

    term = next((change for change in changes if change.starts_on == month), None)

    if term is None:
        term = CompensationTerm(staff_tax_code=staff.tax_code, starts_on=month)
        changes.append(term)
        db.add(term)

    term.collaboration_type = collaboration_type
    term.gross_compensation = gross_compensation

    latest = max(changes, key=lambda change: change.starts_on)

    staff.collaboration_type = latest.collaboration_type
    staff.gross_compensation = latest.gross_compensation

    await db.flush()


# Each day takes what the running total grew by, so the days add up to the month
# whatever the rate, and the month is the paid hours times the rate.
def _priced_days(
    days: Mapping[date, list[Span]],
    volunteer: Mapping[date, list[Span]],
    rate: Decimal | None,
    online: Mapping[date, list[Span]],
) -> tuple[list[CompensationDay], Decimal | None, Decimal | None]:
    rows: list[CompensationDay] = []
    paid = 0
    gross_total = _ZERO
    net_total = _ZERO

    for day in sorted(days):
        worked = days[day]
        given = volunteer.get(day, [])
        gross = net = None

        if rate is not None:
            paid += span_minutes(worked) - span_minutes(given)
            gross_now = amount(paid, rate)
            net_now = net_of(gross_now)
            gross = gross_now - gross_total
            net = net_now - net_total
            gross_total = gross_now
            net_total = net_now

        rows.append(
            CompensationDay(day, worked, given, gross, net, online.get(day, [])),
        )

    if rate is None:
        return rows, None, None

    return rows, gross_total, net_total


# A confirmed band says what an admin checked; the calendar speaks for the others.
async def worked_bands(
    db: AsyncSession,
    tax_code: str,
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
) -> list[BandWork]:
    confirmed = await confirmed_bands(db, start, end)
    calendar = band_work(
        row
        for row in await teacher_rows(db, tax_code, start, end, is_over)
        if (row[1], row[2]) not in confirmed
    )

    return sorted(
        [*calendar, *await confirmed_work(db, tax_code, start, end)],
        key=lambda work: work.key,
    )


async def worked_days(
    db: AsyncSession,
    tax_code: str,
    start: date,
    end: date,
    is_over: Callable[[date, time], bool],
) -> dict[date, list[Span]]:
    return days_of(await worked_bands(db, tax_code, start, end, is_over))


def _online_by_day(bands: Sequence[BandWork]) -> dict[date, list[Span]]:
    by_day: dict[date, list[Span]] = defaultdict(list)

    for work in bands:
        if not work.presence:
            by_day[work.day].extend(work.spans)

    return {day: merge(spans) for day, spans in by_day.items()}


async def month_compensation(
    db: AsyncSession,
    tax_code: str,
    month: date,
    is_over: Callable[[date, time], bool],
    timeline: TermsTimeline,
) -> CompensationMonth:
    [pay] = await months_compensation(db, tax_code, [month], is_over, timeline)

    return pay


# One read for the stretch: weeks and days owe their hour as they would month by month.
async def months_compensation(
    db: AsyncSession,
    tax_code: str,
    months: Sequence[date],
    is_over: Callable[[date, time], bool],
    timeline: TermsTimeline,
) -> list[CompensationMonth]:
    if not months:
        return []

    # A week begun in the month before may have given its hour there.
    bands = await worked_bands(
        db,
        tax_code,
        monday_of(min(months)),
        month_after(max(months)),
        is_over,
    )

    return _priced_months(bands, months, timeline)


# The month under each rule, were it the teacher's from this month on.
async def rule_previews(
    db: AsyncSession,
    tax_code: str,
    month: date,
    is_over: Callable[[date, time], bool],
    timeline: TermsTimeline,
) -> dict[VolunteeringRule, CompensationMonth]:
    bands = await worked_bands(
        db,
        tax_code,
        monday_of(month),
        month_after(month),
        is_over,
    )

    return {
        choice: _priced_months(
            bands,
            [month],
            replace(timeline, month_rules={**timeline.month_rules, month: choice}),
        )[0]
        for choice in VolunteeringRule
    }


def _priced_months(
    bands: Sequence[BandWork],
    months: Sequence[date],
    timeline: TermsTimeline,
) -> list[CompensationMonth]:
    days = days_of(bands)
    online = _online_by_day(bands)
    volunteer = volunteer_by_day(
        allot_volunteering(bands, timeline.counts, timeline.rule),
    )
    paid: list[CompensationMonth] = []

    for month in months:
        terms = timeline.of_month(month)
        end = month_after(month)
        shown = {day: spans for day, spans in days.items() if month <= day < end}
        rows, gross, net = _priced_days(
            shown,
            volunteer if terms.is_paid else {},
            terms.rate,
            online,
        )
        paid.append(CompensationMonth(terms=terms, days=rows, gross=gross, net=net))

    return paid
