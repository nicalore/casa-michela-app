from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.alphabetical_order import alphabetical_key
from app.models.person import Person
from app.models.student_hours import (
    StudentConfirmedBand,
    StudentConfirmedHours,
    StudentHoursCorrection,
)
from app.models.student_payment import (
    HoursKindEnum,
    StudentPayment,
    StudentPaymentKindEnum,
)
from app.models.student_tariff import StudentTariff, TariffKindEnum
from app.services.enrollment_spans import EnrolledSpan, hours_spans, is_enrolled_on
from app.services.standard_tariffs import PaymentRates
from app.services.student_hours import pupil_band_ends
from app.services.student_payments import (
    PaymentStatus,
    PupilLesson,
    SettledLesson,
    payment_status,
    pupil_books,
    tariff_timeline,
)
from app.services.teacher_month import openings_to_come
from app.services.worked_hours import BAND_ORDER, ONLINE, minutes_of, month_after

# Where a pupil stands: the daily summary's situations, over the whole account, and
# SETTLED for an hourly tariff with nothing left to pay.
StandingKind = Literal[
    "NONE",
    "PACKAGE_LEFT",
    "PACKAGE_ENDED",
    "MONTH_PAID",
    "MONTH_UNPAID",
    "SETTLE",
    "SETTLED",
    "AHEAD_LEFT",
    "AHEAD_ENDED",
]


@dataclass(frozen=True)
class Standing:
    kind: StandingKind
    # Left of the package or of the hours paid ahead; once they ran out, those of
    # them not covered.
    minutes: int = 0
    # All that is left to settle.
    due_cents: int = 0
    # Another package already bought, waiting for this one to end.
    renewal: bool = False


# Under one tariff, what the month holds: its days and hours.
@dataclass(frozen=True)
class TariffPart:
    kind: TariffKindEnum | None
    amount_cents: int | None
    package_hours: int | None
    # The day it took over, when later than the month's first; its last day, when
    # earlier than the month's last.
    starts_on: date | None
    ends_on: date | None
    days: int
    presence_days: int
    online_days: int
    minutes: int
    presence_minutes: int
    online_minutes: int


@dataclass(frozen=True)
class StudentMonthRow:
    tax_code: str
    first_name: str
    last_name: str
    parts: list[TariffPart]
    # None once a later month has a day confirmed.
    standing: Standing | None


@dataclass(frozen=True)
class StudentMonthSummary:
    month: date
    rows: list[StudentMonthRow]
    # Over and still to confirm, in time order.
    pending: list[tuple[date, str]]
    finished: bool
    # The day the situations stand at: the month's last once it is over or past,
    # else None for today.
    standing_on: date | None
    # Until a day of a later month is confirmed: from then on the pupils'
    # situation is the later month's.
    standing_shown: bool


# A stretch of confirmed lesson: its day, its mode, its minutes.
_Stretch = tuple[date, str, int]


# Everything of a pupil's account the summary reads.
@dataclass(frozen=True)
class _Ledger:
    tariffs: list[StudentTariff]
    payments: list[StudentPayment]
    lessons: list[PupilLesson]
    settled: list[SettledLesson]
    rates: PaymentRates
    spans: list[EnrolledSpan]


def _arrived(day: date, end: time, now: datetime) -> bool:
    return day < now.date() or (day == now.date() and end <= now.time())


def _last_day(month: date) -> date:
    return month_after(month) - timedelta(days=1)


async def _confirmations(
    db: AsyncSession,
    start: date,
    end: date,
) -> dict[tuple[date, str], bool]:
    rows = await db.execute(
        select(
            StudentConfirmedBand.date,
            StudentConfirmedBand.band,
            StudentConfirmedBand.reopened,
        ).where(
            StudentConfirmedBand.date >= start,
            StudentConfirmedBand.date < end,
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
                StudentHoursCorrection.student_tax_code,
                StudentHoursCorrection.date,
                StudentHoursCorrection.band,
            ).where(
                StudentHoursCorrection.added.is_(True),
                StudentHoursCorrection.date >= start,
                StudentHoursCorrection.date < end,
            ),
        )
    ).tuples().all()
    # As the daily summary: nobody has hours on a day they were not enrolled.
    spans = await hours_spans(db, {pupil for pupil, _, _ in rows})

    return {
        (day, band)
        for pupil, day, band in rows
        if is_enrolled_on(day, spans.get(pupil, []))
    }


# As the teachers' month: every band over with pupils in it confirmed, and nothing
# more to come before the month ends.
async def _month_state(
    db: AsyncSession,
    month: date,
    now: datetime,
) -> tuple[list[tuple[date, str]], bool]:
    end = month_after(month)
    ends = await pupil_band_ends(db, month, end)
    added = await _added_bands(db, month, end)
    confirmations = await _confirmations(db, month, end)

    pending: set[tuple[date, str]] = set()
    coming = False

    for key in {*ends, *added, *confirmations}:
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

    ordered = sorted(pending, key=lambda key: (key[0], BAND_ORDER[key[1]]))

    return ordered, not pending and not coming


def standing_of(
    status: PaymentStatus | None,
    payments: Sequence[StudentPayment],
) -> Standing:
    if status is None:
        return Standing("NONE")

    row = status.tariff
    due = status.due_cents

    if row.kind == TariffKindEnum.PACKAGE:
        package = status.package

        if package is not None and package.running:
            return Standing(
                "PACKAGE_LEFT",
                minutes=package.hours * 60 - package.used_minutes,
                due_cents=due,
                renewal=status.queued == "PACKAGE",
            )

        over = status.line(HoursKindEnum.OVER_PACKAGE)

        return Standing(
            "PACKAGE_ENDED",
            minutes=0 if over is None else over.minutes,
            due_cents=due,
        )

    if row.kind == TariffKindEnum.MONTHLY:
        if status.month_paid:
            return Standing("MONTH_PAID", due_cents=due)

        if status.state == "RENEW":
            return Standing("MONTH_UNPAID", due_cents=due)

        return Standing("SETTLE" if due else "SETTLED", due_cents=due)

    ahead = status.ahead

    if ahead is not None:
        return Standing(
            "AHEAD_LEFT",
            minutes=ahead.total_minutes - ahead.used_minutes,
            due_cents=due,
        )

    hourly = status.line(HoursKindEnum.HOURLY)
    paid_ahead = any(item.kind == StudentPaymentKindEnum.AHEAD for item in payments)

    if hourly is not None and hourly.minutes > 0 and paid_ahead:
        return Standing("AHEAD_ENDED", minutes=hourly.minutes, due_cents=due)

    return Standing("SETTLE" if due else "SETTLED", due_cents=due)


# The account as it stood at the end of a day: lessons and payments up to it only.
def _standing(ledger: _Ledger, day: date) -> Standing:
    if not ledger.tariffs:
        return Standing("NONE")

    payments = [item for item in ledger.payments if item.paid_on <= day]
    kept = {item.id for item in payments}
    settled: dict[int, int] = defaultdict(int)

    for item in ledger.settled:
        if item.payment_id in kept:
            settled[item.lesson.id] += item.minutes

    status = payment_status(
        ledger.tariffs,
        payments,
        settled,
        [lesson for lesson in ledger.lessons if lesson.day <= day],
        ledger.spans,
        day,
        ledger.rates,
    )

    return standing_of(status, payments)


def _part(
    row: StudentTariff | None,
    shown: tuple[int, int | None] | None,
    starts_on: date | None,
    ends_on: date | None,
    stretches: Sequence[_Stretch],
) -> TariffPart:
    presence = [stretch for stretch in stretches if stretch[1] != ONLINE]
    online = [stretch for stretch in stretches if stretch[1] == ONLINE]

    return TariffPart(
        kind=None if row is None else row.kind,
        amount_cents=None if shown is None else shown[0],
        package_hours=None if shown is None else shown[1],
        starts_on=starts_on,
        ends_on=ends_on,
        days=len({day for day, _, _ in stretches}),
        presence_days=len({day for day, _, _ in presence}),
        online_days=len({day for day, _, _ in online}),
        minutes=sum(minutes for _, _, minutes in stretches),
        presence_minutes=sum(minutes for _, _, minutes in presence),
        online_minutes=sum(minutes for _, _, minutes in online),
    )


# One part per tariff the month's lessons fall under, in order.
def _parts(
    ledger: _Ledger,
    month: date,
    stretches: Sequence[_Stretch],
    now: datetime,
) -> list[TariffPart]:
    end = month_after(month)
    last = _last_day(month)

    if not ledger.tariffs:
        return [_part(None, None, None, None, stretches)]

    until = min(last, now.date())
    settled: dict[int, int] = defaultdict(int)

    for item in ledger.settled:
        settled[item.lesson.id] += item.minutes

    timeline = tariff_timeline(
        ledger.tariffs,
        ledger.payments,
        settled,
        [lesson for lesson in ledger.lessons if lesson.day <= until],
        until,
        ledger.rates,
    )
    rows = timeline.rows

    def in_force(day: date) -> StudentTariff | None:
        current: StudentTariff | None = None

        for row in rows:
            if row.id in timeline.reached and timeline.starts[row.id] <= day:
                current = row

        return current

    lessons_of: dict[int | None, list[_Stretch]] = defaultdict(list)

    for stretch in stretches:
        row = in_force(stretch[0])
        lessons_of[None if row is None else row.id].append(stretch)

    def shown(row: StudentTariff) -> tuple[int, int | None]:
        if row.kind == TariffKindEnum.PACKAGE:
            packages = [
                item
                for item in ledger.payments
                if item.kind == StudentPaymentKindEnum.PACKAGE
                and item.tariff_id == row.id
            ]
            used = [
                item
                for item in packages
                if any(month <= day < end for day in timeline.covered.get(item.id, []))
            ]
            picked = used or [item for item in packages if month <= item.paid_on < end]

            if picked:
                package = max(picked, key=lambda item: (item.paid_on, item.id))

                return package.amount_cents, package.package_hours

            return row.amount_cents, row.package_hours

        if row.kind == TariffKindEnum.MONTHLY:
            fee = next(
                (
                    item
                    for item in ledger.payments
                    if item.kind == StudentPaymentKindEnum.MONTH
                    and item.tariff_id == row.id
                    and item.month == month
                ),
                None,
            )

            return (row.amount_cents if fee is None else fee.amount_cents), None

        return row.amount_cents, None

    parts: list[TariffPart] = []

    if lessons_of.get(None):
        parts.append(_part(None, None, None, None, lessons_of[None]))

    for index, row in enumerate(rows):
        if not lessons_of.get(row.id):
            continue

        # A tariff that should have begun and waits for a package to end has no
        # known day yet.
        def known(tariff: StudentTariff) -> bool:
            return tariff.id in timeline.reached or tariff.starts_on > until

        start = timeline.starts[row.id]
        ends_on: date | None = None

        if index + 1 < len(rows) and known(rows[index + 1]):
            next_start = timeline.starts[rows[index + 1].id]

            if next_start <= last:
                ends_on = next_start - timedelta(days=1)

        parts.append(
            _part(
                row,
                shown(row),
                start if known(row) and start > month else None,
                ends_on,
                lessons_of[row.id],
            ),
        )

    return parts


# Who the month holds: their confirmed stretches.
async def _pupils_of(
    db: AsyncSession,
    month: date,
) -> dict[str, list[_Stretch]]:
    end = month_after(month)
    hours = await db.execute(
        select(
            StudentConfirmedHours.student_tax_code,
            StudentConfirmedHours.date,
            StudentConfirmedHours.mode,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
        ).where(
            StudentConfirmedHours.date >= month,
            StudentConfirmedHours.date < end,
        ),
    )
    stretches: dict[str, list[_Stretch]] = defaultdict(list)

    for tax_code, day, mode, start, finish in hours.tuples():
        stretches[tax_code].append(
            (day, mode, minutes_of(finish) - minutes_of(start)),
        )

    return dict(stretches)


async def _ledgers(
    db: AsyncSession,
    tax_codes: Sequence[str],
    now: datetime,
) -> dict[str, _Ledger]:
    return {
        tax_code: _Ledger(
            book.tariffs,
            book.payments,
            book.lessons,
            book.settled,
            book.rates,
            book.spans,
        )
        for tax_code, book in (await pupil_books(db, tax_codes, now)).items()
    }


# A day confirmed in a month after this one: where the pupils stand is read there.
async def _superseded(db: AsyncSession, month: date) -> bool:
    later = await db.scalar(
        select(StudentConfirmedBand.date)
        .where(StudentConfirmedBand.date >= month_after(month))
        .limit(1),
    )

    return later is not None


# One row per pupil with a confirmed lesson in the month.
async def month_summary(
    db: AsyncSession,
    month: date,
    now: datetime,
) -> StudentMonthSummary:
    pending, finished = await _month_state(db, month, now)
    pupils = await _pupils_of(db, month)

    people = await db.execute(
        select(Person.tax_code, Person.first_name, Person.last_name).where(
            Person.tax_code.in_(list(pupils)),
        ),
    )
    names = {tax_code: (first, last) for tax_code, first, last in people.tuples()}
    ordered = sorted(names, key=lambda code: alphabetical_key(*names[code]))
    ledgers = await _ledgers(db, ordered, now)

    last = _last_day(month)
    shown = not await _superseded(db, month)

    # Never kept: worked out at every reading, and never past the month's last
    # day, even with bands of it still to confirm.
    standings = (
        {
            tax_code: _standing(ledger, min(now.date(), last))
            for tax_code, ledger in ledgers.items()
        }
        if shown
        else {}
    )

    rows = [
        StudentMonthRow(
            tax_code=tax_code,
            first_name=names[tax_code][0],
            last_name=names[tax_code][1],
            parts=_parts(ledgers[tax_code], month, pupils[tax_code], now),
            standing=standings.get(tax_code),
        )
        for tax_code in ordered
    ]

    return StudentMonthSummary(
        month=month,
        rows=rows,
        pending=pending,
        finished=finished,
        standing_on=last if shown and (finished or now.date() > last) else None,
        standing_shown=shown,
    )
