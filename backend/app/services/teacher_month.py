from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.alphabetical_order import alphabetical_key
from app.core.availability_thresholds import LOW_AVAILABILITY_MONTHLY_THRESHOLD
from app.core.booking_close import has_closed
from app.core.time_band import TimeBandEnum, band_bounds, band_of
from app.models.accounting_opening import TeacherOpening
from app.models.availability import Availability
from app.models.confirmed_hours import (
    ConfirmedBand,
    ConfirmedHours,
    HoursCorrection,
)
from app.models.opening_day import OpeningDay
from app.models.person import Person
from app.models.presence import Presence
from app.models.staff import CollaborationTypeEnum
from app.models.teacher import Teacher
from app.models.volunteering import VolunteeringMonth, VolunteeringRule
from app.services.availability_weeks import days_given, opening_weeks, weeks_of
from app.services.compensation import (
    allot_volunteering,
    amount,
    load_terms,
    monday_of,
    net_of,
    worked_bands,
)
from app.services.enrollment_spans import (
    enrolled_spans,
    enrolled_throughout,
    hours_spans,
    is_enrolled_on,
)
from app.services.opening_state import collaborating, money_from
from app.services.payment_receipts import ReceiptInfo, receipts_of_month
from app.services.worked_hours import (
    BAND_ORDER,
    band_last_ends,
    month_after,
    published_pairs,
    span_minutes,
)

_TEACHER_NOT_FOUND_ERROR: Final[str] = "Docente non trovato."
_NOT_PAID_ERROR: Final[str] = (
    "L'ora di volontariato si conta solo a chi è retribuito in quel mese."
)


# A paid teacher's unpaid hour and pay under one rule.
@dataclass(frozen=True)
class RuleFigures:
    volunteer_minutes: int
    paid_minutes: int
    gross: Decimal | None
    net: Decimal | None


@dataclass(frozen=True)
class MonthRow:
    tax_code: str
    first_name: str
    last_name: str
    collaboration_type: CollaborationTypeEnum
    days: int
    presence_days: int
    online_days: int
    worked_minutes: int
    volunteer_minutes: int
    # None where nothing is paid.
    paid_minutes: int | None
    gross: Decimal | None
    net: Decimal | None
    availabilities: int
    below_monthly: bool
    short_weeks: int
    # How this month counts the unpaid hour, and what the teacher's Compensi say.
    volunteering: VolunteeringRule
    standing_volunteering: VolunteeringRule
    # Under each rule for this month alone, shown while one is picked and not saved.
    rule_figures: dict[VolunteeringRule, RuleFigures] | None
    receipt: ReceiptInfo | None
    # Its initial set-up is still to do: no money yet.
    opening_pending: bool = False


@dataclass(frozen=True)
class MonthSummary:
    month: date
    rows: list[MonthRow]
    # Over and still to confirm, in time order.
    pending: list[tuple[date, str]]
    # Nothing left to confirm and nothing more to come before the month ends.
    finished: bool


def _arrived(day: date, end: time, now: datetime) -> bool:
    return day < now.date() or (day == now.date() and end <= now.time())


def _ordered(keys: set[tuple[date, str]]) -> list[tuple[date, str]]:
    return sorted(keys, key=lambda key: (key[0], BAND_ORDER[key[1]]))


async def _confirmations(
    db: AsyncSession,
    start: date,
    end: date,
) -> dict[tuple[date, str], bool]:
    rows = await db.execute(
        select(ConfirmedBand.date, ConfirmedBand.band, ConfirmedBand.reopened).where(
            ConfirmedBand.date >= start,
            ConfirmedBand.date < end,
        ),
    )

    return {(day, band): reopened for day, band, reopened in rows.tuples()}


async def _added_bands(
    db: AsyncSession,
    start: date,
    end: date,
) -> set[tuple[date, str]]:
    rows = (
        await db.execute(
            select(
                HoursCorrection.teacher_tax_code,
                HoursCorrection.date,
                HoursCorrection.band,
            ).where(
                HoursCorrection.added.is_(True),
                HoursCorrection.date >= start,
                HoursCorrection.date < end,
            ),
        )
    ).tuples().all()
    # As the daily summary: nobody has hours on a day they were not enrolled.
    spans = await hours_spans(db, {teacher for teacher, _, _ in rows})

    return {
        (day, band)
        for teacher, day, band in rows
        if is_enrolled_on(day, spans.get(teacher, []))
    }


# Open bands still to come without a calendar that may yet have one: bookings still
# open, or somebody booked. Closed with nobody booked, nothing will come there: the
# calendar is never published (CalendarPublicationService.unbooked_bands).
async def openings_to_come(
    db: AsyncSession,
    end: date,
    now: datetime,
) -> bool:
    today = now.date()

    if today >= end:
        return False

    slots = await db.execute(
        select(OpeningDay.date, OpeningDay.start_time, OpeningDay.end_time).where(
            OpeningDay.start_time.is_not(None),
            OpeningDay.date >= today,
            OpeningDay.date < end,
        ),
    )

    published = await published_pairs(db, today, end)
    starts = await db.execute(
        select(Presence.date, Presence.start_time).where(
            Presence.date >= today,
            Presence.date < end,
        ),
    )
    booked = {(day, band_of(start).value) for day, start in starts.tuples()}

    for day, opens, closes in slots.tuples():
        if opens is None or closes is None:
            continue

        for band in TimeBandEnum:
            low, high = band_bounds(band)
            key = (day, band.value)

            if opens >= high or closes <= low or key in published:
                continue

            if has_closed(day, band, now) and key not in booked:
                continue

            if not _arrived(day, min(closes, high), now):
                return True

    return False


# The month's bands, as confirming sees them: what is over and owes a confirmation,
# and whether anything is still to come.
async def _month_state(
    db: AsyncSession,
    month: date,
    now: datetime,
) -> tuple[list[tuple[date, str]], bool]:
    end = month_after(month)
    ends = await band_last_ends(db, month, end)
    added = await _added_bands(db, month, end)
    confirmations = await _confirmations(db, month, end)
    first = await money_from(db)

    pending: set[tuple[date, str]] = set()
    coming = False

    for key in {*ends, *added, *confirmations}:
        # The set-up covers the bands before the accounting start.
        if first is not None and key[0] < first:
            continue

        reopened = confirmations.get(key)

        if reopened is False:
            continue

        last_end = ends.get(key)

        if reopened or last_end is None or _arrived(key[0], last_end, now):
            pending.add(key)
        else:
            coming = True

    if not coming:
        coming = await openings_to_come(db, end, now)

    return _ordered(pending), not pending and not coming


async def _availabilities(
    db: AsyncSession,
    tax_codes: Sequence[str],
    month: date,
    today: date,
) -> dict[str, tuple[int, bool, int]]:
    if not tax_codes:
        return {}

    end = month_after(month)
    until = min(end, today + timedelta(days=1))

    counts = await db.execute(
        select(
            Availability.teacher_tax_code,
            func.count(func.distinct(Availability.date)),
        )
        .where(
            Availability.teacher_tax_code.in_(tax_codes),
            Availability.mode == "presence",
            Availability.date >= month,
            Availability.date < until,
        )
        .group_by(Availability.teacher_tax_code),
    )
    given = {tax_code: count for tax_code, count in counts.tuples()}

    spans = await enrolled_spans(db, tax_codes)
    weeks = await opening_weeks(db, month, end, today)
    by_week = await days_given(db, weeks)

    out: dict[str, tuple[int, bool, int]] = {}

    for tax_code in tax_codes:
        enrolled = spans.get(tax_code, [])
        total = given.get(tax_code, 0)
        short = sum(
            1
            for week in weeks_of(weeks.frames(enrolled), by_week.get(tax_code, {}))
            if week.is_short
        )
        below = total < LOW_AVAILABILITY_MONTHLY_THRESHOLD and enrolled_throughout(
            enrolled,
            month,
            until,
        )
        out[tax_code] = (total, below, short)

    return out


async def _row(
    db: AsyncSession,
    tax_code: str,
    name: tuple[str, str],
    month: date,
    confirmed: set[tuple[date, str]],
    is_over: Callable[[date, time], bool],
    availability: tuple[int, bool, int],
    receipt: ReceiptInfo | None,
) -> MonthRow:
    timeline = await load_terms(db, tax_code)
    terms = timeline.of_month(month)

    # A week begun in the month before may have given its hour there.
    bands = await worked_bands(
        db,
        tax_code,
        monday_of(month),
        month_after(month),
        is_over,
    )
    mine = [
        work
        for work in bands
        if work.day >= month and (work.day, work.band) in confirmed
    ]

    worked = sum(span_minutes(work.spans) for work in mine)
    kind = terms.collaboration_type
    rate = terms.rate

    def figures(rule: Callable[[date], VolunteeringRule]) -> RuleFigures:
        allotted = allot_volunteering(bands, timeline.counts, rule)
        given = sum(
            span_minutes(allotted.get((work.day, work.band), [])) for work in mine
        )
        # Band by band, as Compensi and the daily summary price them.
        gross = (
            None
            if rate is None or not timeline.prices(month)
            else sum(
                (
                    amount(
                        span_minutes(work.spans)
                        - span_minutes(allotted.get((work.day, work.band), [])),
                        rate,
                    )
                    for work in mine
                    if timeline.counted(work.day)
                ),
                timeline.opening_in(month) or Decimal(0),
            )
        )

        return RuleFigures(
            volunteer_minutes=given,
            paid_minutes=worked - given,
            gross=gross,
            net=None if gross is None else net_of(gross),
        )

    after = month_after(month)

    # This month alone counted so; the rest stays as it is.
    def only_here(choice: VolunteeringRule) -> Callable[[date], VolunteeringRule]:
        def rule(day: date) -> VolunteeringRule:
            return choice if month <= day < after else timeline.rule(day)

        return rule

    chosen = timeline.rule(month)
    each: dict[VolunteeringRule, RuleFigures] | None = None
    current: RuleFigures | None = None

    if terms.is_paid:
        each = {choice: figures(only_here(choice)) for choice in VolunteeringRule}
        current = each[chosen]

    # A volunteer gives every hour; other unpaid kinds give none and are paid none.
    given = (
        worked
        if kind == CollaborationTypeEnum.VOLUNTEER
        else (0 if current is None else current.volunteer_minutes)
    )

    total, below, short = availability

    return MonthRow(
        tax_code=tax_code,
        first_name=name[0],
        last_name=name[1],
        collaboration_type=kind,
        days=len({work.day for work in mine}),
        presence_days=len({work.day for work in mine if work.presence}),
        online_days=len({work.day for work in mine if not work.presence}),
        worked_minutes=worked,
        volunteer_minutes=given,
        paid_minutes=None if current is None else current.paid_minutes,
        gross=None if current is None else current.gross,
        net=None if current is None else current.net,
        availabilities=total,
        below_monthly=below,
        short_weeks=short,
        volunteering=chosen,
        standing_volunteering=timeline.standing_rule(month),
        rule_figures=each,
        receipt=receipt,
        opening_pending=terms.is_paid and timeline.pending_in(month),
    )


# One row per teacher with confirmed hours in the month: only confirmed bands count.
async def month_summary(
    db: AsyncSession,
    month: date,
    now: datetime,
    is_over: Callable[[date, time], bool],
) -> MonthSummary:
    end = month_after(month)
    confirmed = set(await _confirmations(db, month, end))

    listed = select(ConfirmedHours.teacher_tax_code).where(
        ConfirmedHours.date >= month,
        ConfirmedHours.date < end,
    )
    first = await money_from(db)

    # The set-up's month also lists who was paid before money_from, or waits for it.
    if first is not None and month < first < end:
        waiting = await collaborating(
            db,
            list(
                await db.scalars(
                    select(TeacherOpening.tax_code).where(
                        TeacherOpening.confirmed_at.is_(None),
                    ),
                )
            ),
        )
        listed = listed.union(
            select(TeacherOpening.tax_code).where(
                or_(TeacherOpening.gross > 0, TeacherOpening.tax_code.in_(waiting)),
            ),
        )

    people = await db.execute(
        select(Person.tax_code, Person.first_name, Person.last_name).where(
            Person.tax_code.in_(listed),
        ),
    )
    names = {
        tax_code: (first, last) for tax_code, first, last in people.tuples()
    }
    ordered = sorted(names, key=lambda code: alphabetical_key(*names[code]))
    availability = await _availabilities(db, ordered, month, now.date())
    receipts = await receipts_of_month(db, month)

    rows = [
        await _row(
            db,
            tax_code,
            names[tax_code],
            month,
            confirmed,
            is_over,
            availability[tax_code],
            receipts.get(tax_code),
        )
        for tax_code in ordered
    ]

    pending, finished = await _month_state(db, month, now)

    return MonthSummary(month=month, rows=rows, pending=pending, finished=finished)


# This month alone counted otherwise than the teacher's rule; the next one follows
# the rule again. Gives what the month counted before, or None when it is unchanged:
# only then is the teacher told.
async def set_month_volunteering(
    db: AsyncSession,
    tax_code: str,
    month: date,
    rule: VolunteeringRule,
) -> VolunteeringRule | None:
    if await db.get(Teacher, tax_code) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_TEACHER_NOT_FOUND_ERROR,
        )

    timeline = await load_terms(db, tax_code)

    if not timeline.of_month(month).is_paid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NOT_PAID_ERROR,
        )

    before = timeline.rule(month)

    if before == rule:
        return None

    row = await db.get(VolunteeringMonth, (tax_code, month))

    if rule == timeline.standing_rule(month):
        if row is not None:
            await db.delete(row)
    elif row is None:
        db.add(
            VolunteeringMonth(teacher_tax_code=tax_code, month=month, rule=rule.value),
        )
    else:
        row.rule = rule.value

    await db.flush()

    return before
