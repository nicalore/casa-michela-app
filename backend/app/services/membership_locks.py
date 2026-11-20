from collections import defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import ColumnElement, and_, delete, false, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import InstrumentedAttribute

from app.core.i18n import ENGLISH, request_language
from app.models.confirmed_hours import ConfirmedHours, ConfirmedVolunteering
from app.models.membership import Membership
from app.models.membership_fee import MembershipFee, MembershipFeeKindEnum
from app.models.payment_receipt import PaymentReceipt
from app.models.student_hours import StudentConfirmedHours
from app.models.student_payment import StudentPayment, StudentPaymentBand
from app.models.student_tariff import StudentTariff
from app.schemas.person import MembershipUpdateItem
from app.services.bilingual import Bilingual
from app.services.enrollment_spans import (
    EnrolledSpan,
    YearRow,
    first_shared_day,
    spans_of,
    without,
)
from app.services.membership_fees import FEE_KINDS, member_fees
from app.services.student_payments import pupil_lessons, student_payment_status
from app.services.worked_hours import minutes_of, month_after
from app.services.write_losses import Losses

_PAID_IN_PERIOD_ERROR: Final[Bilingual] = Bilingual(
    "Impossibile togliere l'iscrizione: ci sono pagamenti registrati "
    "nel periodo coinvolto.",
    "The enrolment cannot be removed: there are payments recorded in the "
    "period involved.",
)
_LOSSES_NOTE: Final[str] = "Togliendo l'iscrizione si cancellano anche {losses}."
_LOSS_NOTE: Final[str] = "Togliendo l'iscrizione si cancella anche {losses}."
_ENGLISH_LOSS_NOTE: Final[str] = "Removing the enrolment also deletes {losses}."

_FEE_LABELS: Final[dict[MembershipFeeKindEnum, Bilingual]] = {
    MembershipFeeKindEnum.MEMBERSHIP: Bilingual("Iscrizione", "Enrolment"),
    MembershipFeeKindEnum.INSURANCE: Bilingual("Assicurazione", "Insurance"),
}

_ONE_DAY: Final[timedelta] = timedelta(days=1)

_HoursTable = type[StudentConfirmedHours] | type[ConfirmedHours]


@dataclass(frozen=True)
class YearLock:
    # Neither removed nor moved to another year.
    locked: bool
    # The start may not go past this day.
    latest_start: date | None


def _year_rows(rows: Iterable[Membership | MembershipUpdateItem]) -> list[YearRow]:
    return [
        YearRow(row.year, row.start_date, row.end_date, row.renewal_period_days)
        for row in rows
    ]


def _euro(cents: int, english: bool) -> str:
    units, fraction = divmod(cents, 100)

    if english:
        return f"€{units:,}.{fraction:02d}"

    return f"€ {units:,}".replace(",", ".") + f",{fraction:02d}"


def _listed(items: Sequence[str], english: bool = False) -> str:
    if len(items) == 1:
        return items[0]

    return f"{', '.join(items[:-1])} {'and' if english else 'e'} {items[-1]}"


# «4h 45m», «45m», «2h» like formatMinutes in the app.
def _minutes_said(minutes: int) -> str:
    hours, rest = divmod(minutes, 60)

    if not hours:
        return f"{rest}m"

    return f"{hours}h {rest}m" if rest else f"{hours}h"


# In the language of whoever asked.
def _losses_note(fees: Sequence[MembershipFee], minutes: int) -> str:
    english = request_language() == ENGLISH
    losses: list[str] = []

    if fees:
        said = [
            f"{_FEE_LABELS[fee.kind].for_request()} {fee.year} "
            f"{_euro(fee.amount_cents, english)}"
            for fee in sorted(
                fees,
                key=lambda row: (row.year, FEE_KINDS.index(row.kind)),
            )
        ]
        listed = _listed(said, english)

        if english:
            losses.append(
                f"the fee due ({listed})" if len(said) == 1
                else f"the fees due ({listed})",
            )
        else:
            losses.append(
                f"la quota da pagare ({listed})" if len(said) == 1
                else f"le quote da pagare ({listed})",
            )

    if minutes:
        hours = _minutes_said(minutes)
        losses.append(
            f"{hours} of confirmed unpaid hours" if english
            else f"{hours} di ore confermate non pagate",
        )

    if english:
        return _ENGLISH_LOSS_NOTE.format(losses=_listed(losses, english))

    # The verb agrees with the whole list: singular for one fee, 1h or 1m alone.
    one = len(losses) == 1 and len(fees) <= 1 and minutes in (0, 1, 60)
    note = _LOSS_NOTE if one else _LOSSES_NOTE

    return note.format(losses=_listed(losses))


def _within(
    column: InstrumentedAttribute[date],
    spans: Sequence[EnrolledSpan],
) -> ColumnElement[bool]:
    return or_(
        false(),
        *(and_(column >= first, column < after) for first, after in spans),
    )


# Lessons a package, a month or hours paid ahead or settled took, even in part.
async def _covered_days(db: AsyncSession, tax_code: str, now: datetime) -> set[date]:
    since = await db.scalar(
        select(func.min(StudentTariff.starts_on)).where(
            StudentTariff.student_tax_code == tax_code,
        ),
    )

    if since is None:
        return set()

    account = (await student_payment_status(db, tax_code, now)).status

    if account is None:
        return set()

    owed: dict[int, int] = defaultdict(int)

    for line in account.lines:
        for part in line.parts:
            owed[part.lesson_id] += part.minutes

    return {
        lesson.day
        for lesson in await pupil_lessons(db, tax_code, since, now)
        if lesson.minutes > owed[lesson.id]
    }


# The days payments hang on: paid on, months paid, lessons covered, receipts.
async def paid_spans(
    db: AsyncSession,
    tax_code: str,
    now: datetime,
) -> list[EnrolledSpan]:
    days = await _covered_days(db, tax_code, now)
    months: set[date] = set()

    payments = await db.execute(
        select(StudentPayment.paid_on, StudentPayment.month).where(
            StudentPayment.student_tax_code == tax_code,
        ),
    )

    for paid_on, month in payments.tuples():
        days.add(paid_on)

        if month is not None:
            months.add(month.replace(day=1))

    days.update(
        await db.scalars(
            select(StudentPaymentBand.date)
            .join(StudentPayment, StudentPayment.id == StudentPaymentBand.payment_id)
            .where(StudentPayment.student_tax_code == tax_code),
        ),
    )
    months.update(
        await db.scalars(
            select(PaymentReceipt.month).where(
                PaymentReceipt.staff_tax_code == tax_code,
            ),
        ),
    )

    return sorted(
        [(day, day + _ONE_DAY) for day in days]
        + [(month, month_after(month)) for month in months],
    )


def _person_column(table: _HoursTable) -> InstrumentedAttribute[str]:
    if table is StudentConfirmedHours:
        return StudentConfirmedHours.student_tax_code

    return ConfirmedHours.teacher_tax_code


# Hours done while no longer enrolled cannot be: they go with the days.
async def _unpaid_minutes(
    db: AsyncSession,
    tax_code: str,
    lost: Sequence[EnrolledSpan],
) -> int:
    minutes = 0

    for table in (StudentConfirmedHours, ConfirmedHours):
        rows = await db.execute(
            select(table.start_time, table.end_time).where(
                _person_column(table) == tax_code,
                _within(table.date, lost),
            ),
        )
        minutes += sum(
            minutes_of(end) - minutes_of(start) for start, end in rows.tuples()
        )

    return minutes


async def _drop_hours(
    db: AsyncSession,
    tax_code: str,
    lost: Sequence[EnrolledSpan],
) -> None:
    for table in (StudentConfirmedHours, ConfirmedHours):
        await db.execute(
            delete(table).where(
                _person_column(table) == tax_code,
                _within(table.date, lost),
            ),
        )

    await db.execute(
        delete(ConfirmedVolunteering).where(
            ConfirmedVolunteering.teacher_tax_code == tax_code,
            _within(ConfirmedVolunteering.date, lost),
        ),
    )


# One year out and one in, the new one without fees: its number was corrected.
def _renamed_year(
    gone: set[int],
    added: set[int],
    fees: Sequence[MembershipFee],
) -> int | None:
    if len(gone) != 1 or len(added) != 1:
        return None

    (year,) = added

    return None if any(fee.year == year for fee in fees) else year


# Paid periods stay enrolled; owed fees of a year taken away and hours not paid
# in the days taken away go with them, once the admin agrees (losses).
async def guard_lost_enrollment(
    db: AsyncSession,
    tax_code: str,
    before: Iterable[Membership | MembershipUpdateItem],
    after: Iterable[Membership | MembershipUpdateItem],
    *,
    losses: Losses,
    now: datetime,
) -> None:
    before_rows, after_rows = _year_rows(before), _year_rows(after)
    before_years = {row.year for row in before_rows}
    after_years = {row.year for row in after_rows}
    gone_years = before_years - after_years
    lost = without(spans_of(before_rows), spans_of(after_rows))
    fees = await member_fees(db, tax_code)

    if any(fee.paid_on is not None and fee.year in gone_years for fee in fees) or (
        lost and first_shared_day(lost, await paid_spans(db, tax_code, now))
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_PAID_IN_PERIOD_ERROR.for_request(),
        )

    owed = [fee for fee in fees if fee.paid_on is None and fee.year in gone_years]
    renamed_to = _renamed_year(gone_years, after_years - before_years, fees)

    # Only the year's number changed: what is owed follows it, nothing is lost.
    if renamed_to is not None:
        for fee in owed:
            fee.year = renamed_to

        owed = []

    minutes = await _unpaid_minutes(db, tax_code, lost) if lost else 0

    if owed or minutes:
        losses.note(_losses_note(owed, minutes))

    for fee in owed:
        await db.delete(fee)

    if lost:
        await _drop_hours(db, tax_code, lost)

    await db.flush()


# What each year may still undergo in the edit windows; the guard has the last word.
async def year_locks(
    db: AsyncSession,
    tax_code: str,
    rows: Iterable[Membership | MembershipUpdateItem],
    now: datetime,
) -> dict[int, YearLock]:
    paid = await paid_spans(db, tax_code, now)
    paid_years = {
        fee.year for fee in await member_fees(db, tax_code) if fee.paid_on is not None
    }
    listed = _year_rows(rows)
    spans = spans_of(listed)
    locks: dict[int, YearLock] = {}

    for row in listed:
        others = [other for other in listed if other.year != row.year]
        own = without(spans, spans_of(others))
        day = first_shared_day(own, paid) if own else None
        locks[row.year] = YearLock(day is not None or row.year in paid_years, day)

    return locks
