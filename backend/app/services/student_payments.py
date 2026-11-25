from collections import defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field, replace
from datetime import date, datetime, time, timedelta
from typing import Final, Literal

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.member import PaymentMethodEnum
from app.models.person import GenderEnum
from app.models.school_enrollment import SchoolEnrollment
from app.models.student_hours import StudentConfirmedHours
from app.models.student_payment import (
    HoursKindEnum,
    StudentPayment,
    StudentPaymentBand,
    StudentPaymentKindEnum,
)
from app.models.student_tariff import StudentTariff, TariffKindEnum
from app.models.study_program import EducationLevelEnum, StudyProgram
from app.repositories.person_repository import PersonRepository
from app.schemas.student_payments import (
    AheadData,
    PaymentData,
    RenewalData,
    SettlementData,
    StudentTariffData,
    TariffChangeData,
)
from app.services.bilingual import Bilingual
from app.services.enrollment_spans import EnrolledSpan, enrolled_days, enrolled_spans
from app.services.opening_state import (
    PupilStart,
    day_before,
    money_from,
    pupil_start,
    pupil_starts,
)
from app.services.standard_tariffs import (
    PaymentRates,
    enabled_kinds,
    payment_rates,
    rates_of,
    standard_tariff,
    standard_tariffs,
)
from app.services.worked_hours import BAND_ORDER, minutes_of, month_after

_ONLINE: Final[str] = "online"

_SATURDAY: Final[int] = 5

_SCHOOL_YEAR_FIRST_MONTH: Final[int] = 9

_SCHOOL_YEAR_MONTHS: Final[int] = 10

_KIND_DISABLED_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Questa tariffa è disattivata per il livello dello studente.",
        "This rate is turned off for the student's level.",
    ),
    GenderEnum.F: Bilingual(
        "Questa tariffa è disattivata per il livello della studentessa.",
        "This rate is turned off for the student's level.",
    ),
}
_PACKAGE_HOURS_ERROR: Final[Bilingual] = Bilingual(
    "Le ore si indicano solo per il pacchetto.",
    "Hours are given only for the package.",
)
_NO_TARIFF_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Lo studente non ha una tariffa.",
        "The student has no rate.",
    ),
    GenderEnum.F: Bilingual(
        "La studentessa non ha una tariffa.",
        "The student has no rate.",
    ),
}
_ALREADY_RENEWED_ERROR: Final[Bilingual] = Bilingual(
    "Il rinnovo è già fatto.",
    "The renewal is already done.",
)
_ALREADY_CHANGED_ERROR: Final[Bilingual] = Bilingual(
    "La tariffa è già cambiata.",
    "The rate has already changed.",
)
_HOURLY_NOT_RENEWED_ERROR: Final[Bilingual] = Bilingual(
    "La tariffa a ore non si rinnova.",
    "The hourly rate is not renewed.",
)
_SAME_KIND_ERROR: Final[Bilingual] = Bilingual(
    "È già la tariffa attuale.",
    "It is already the current rate.",
)
_MONTH_PAID_ERROR: Final[Bilingual] = Bilingual(
    "La quota di questo mese è già pagata.",
    "This month's fee is already paid.",
)
_DAY_REQUIRED_ERROR: Final[Bilingual] = Bilingual(
    "Manca il giorno.",
    "The day is missing.",
)
_DAY_TOO_EARLY_ERROR: Final[Bilingual] = Bilingual(
    "Il giorno è prima dell'inizio della tariffa attuale.",
    "The day is before the current rate starts.",
)
_PAYMENT_REQUIRED_ERROR: Final[Bilingual] = Bilingual(
    "Manca il pagamento.",
    "The payment is missing.",
)
_PAID_IN_FUTURE_ERROR: Final[Bilingual] = Bilingual(
    "La data del pagamento è nel futuro.",
    "The payment date is in the future.",
)
_NOTHING_TO_SETTLE_ERROR: Final[Bilingual] = Bilingual(
    "Non ci sono ore da saldare.",
    "There are no hours to settle.",
)
_LINE_CHANGED_ERROR: Final[Bilingual] = Bilingual(
    "Le ore da saldare sono cambiate: chiudi la finestra e riaprila.",
    "The hours to settle have changed: close the window and open it again.",
)
_AHEAD_HOURLY_ONLY_ERROR: Final[Bilingual] = Bilingual(
    "Le ore in anticipo si pagano solo con la tariffa a ore.",
    "Hours in advance can be paid only with the hourly rate.",
)
_PAYMENT_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Pagamento non trovato.",
    "Payment not found.",
)
_DAY_IN_FUTURE_ERROR: Final[Bilingual] = Bilingual(
    "Il giorno è nel futuro.",
    "The day is in the future.",
)
_DAY_TOO_FAR_ERROR: Final[Bilingual] = Bilingual(
    "Il giorno è troppo lontano.",
    "The day is too far away.",
)
_BEFORE_ACCOUNTS_ERROR: Final[Bilingual] = Bilingual(
    "Il giorno è prima dell'inizio della contabilità.",
    "The day is before the accounting starts.",
)

# A change waiting to start cannot be taken back: a mistyped year would hold the
# pupil's tariff for good.
_LONGEST_WAIT: Final[timedelta] = timedelta(days=366)

State = Literal["OK", "DUE", "RENEW"]
MonthState = Literal["PAID", "DUE", "NONE"]
Queued = Literal["PACKAGE", "MONTH", "CHANGE"]
HistoryKind = Literal[
    "PACKAGE",
    "MONTH",
    "AHEAD",
    "HOURLY",
    "OVER_PACKAGE",
    "OVER_FEE",
    "WEEKEND_ONLINE",
]
# WAITING: paid ahead, it starts when the one before it ends.
PackageState = Literal["RUNNING", "ENDED", "WAITING", "UNUSED"]

_HISTORY_KINDS: Final[dict[HoursKindEnum, HistoryKind]] = {
    HoursKindEnum.HOURLY: "HOURLY",
    HoursKindEnum.OVER_PACKAGE: "OVER_PACKAGE",
    HoursKindEnum.OVER_FEE: "OVER_FEE",
    HoursKindEnum.WEEKEND_ONLINE: "WEEKEND_ONLINE",
}

_LINE_ORDER: Final[tuple[HoursKindEnum, ...]] = (
    HoursKindEnum.HOURLY,
    HoursKindEnum.OVER_PACKAGE,
    HoursKindEnum.OVER_FEE,
    HoursKindEnum.WEEKEND_ONLINE,
)


_BANDS: Final[tuple[str, ...]] = tuple(BAND_ORDER)

# The bands of the day before money_from that carry the initial set-up's minutes.
_OPENING_PRESENCE: Final[str] = "MORNING"
_OPENING_ONLINE: Final[str] = "AFTERNOON"

OpeningState = Literal["PENDING", "DONE"]


# A pupil's confirmed band, as payments count it: one id per day and band.
@dataclass(frozen=True)
class PupilLesson:
    id: int
    day: date
    start: time
    end: time
    online: bool
    # Several stretches with gaps between them: their sum, not end minus start.
    length: int | None = None
    # Minutes the initial set-up says were taken or owed before money_from.
    opening: bool = False

    @property
    def minutes(self) -> int:
        if self.length is not None:
            return self.length

        return (self.end.hour * 60 + self.end.minute) - (
            self.start.hour * 60 + self.start.minute
        )

    @property
    def weekend_online(self) -> bool:
        return self.online and (self.opening or self.day.weekday() >= _SATURDAY)


@dataclass(frozen=True)
class LessonPart:
    lesson_id: int
    day: date
    minutes: int
    tariff_id: int | None
    # The whole lesson, when another payment has the rest.
    lesson_minutes: int = 0
    cents: int = 0
    opening: bool = False


# A lesson, or the part of it, that one payment covers.
@dataclass(frozen=True)
class HistoryLesson:
    day: date
    minutes: int
    lesson_minutes: int
    # Packages: what is left after it.
    left_minutes: int | None = None
    # Hours paid by the hour: what it costs.
    cents: int | None = None
    exhausted: bool = False
    # Before it was paid: taken when the package was renewed, or the hours paid ahead.
    before_payment: bool = False
    opening: bool = False


@dataclass
class HoursLine:
    kind: HoursKindEnum
    cents_per_hour: int
    parts: list[LessonPart] = field(default_factory=list)
    cents: int = 0

    @property
    def minutes(self) -> int:
        return sum(part.minutes for part in self.parts)


@dataclass(frozen=True)
class PackageStatus:
    hours: int
    amount_cents: int
    used_minutes: int
    ended_on: date | None

    @property
    def running(self) -> bool:
        return self.used_minutes < self.hours * 60


# The hours paid ahead not used up yet, however many payments.
@dataclass(frozen=True)
class AheadStatus:
    total_minutes: int
    used_minutes: int


@dataclass(frozen=True)
class PaymentStatus:
    tariff: StudentTariff
    started_on: date
    # What the next package or month costs.
    amount_cents: int
    package_hours: int | None
    state: State
    package: PackageStatus | None
    months: list[tuple[date, MonthState]] | None
    month_paid: bool
    lines: list[HoursLine]
    queued: Queued | None
    queued_starts_on: date | None
    ahead: AheadStatus | None = None
    # The row a queued change brings in.
    queued_tariff: StudentTariff | None = None

    @property
    def due_cents(self) -> int:
        return sum(line.cents for line in self.lines)

    def line(self, kind: HoursKindEnum) -> HoursLine | None:
        return next((line for line in self.lines if line.kind == kind), None)


# A lesson of another row falls between the first and the last of these days:
# the row then names its days rather than a span.
def days_interleaved(days: Iterable[date], others: Iterable[date]) -> bool:
    own = set(days)

    if not own:
        return False

    first, last = min(own), max(own)

    return any(first < day < last and day not in own for day in others)


def band_unit(day: date, band: str) -> int:
    return day.toordinal() * len(_BANDS) + BAND_ORDER[band]


def unit_band(unit: int) -> tuple[date, str]:
    return date.fromordinal(unit // len(_BANDS)), _BANDS[unit % len(_BANDS)]


# Half a cent goes up, as the windows of the app work it out.
def _cents(minutes: int, cents_per_hour: int) -> int:
    return (minutes * cents_per_hour * 2 + 60) // 120


def _school_year_months(today: date) -> list[date]:
    year = today.year if today.month >= _SCHOOL_YEAR_FIRST_MONTH else today.year - 1
    month = date(year, _SCHOOL_YEAR_FIRST_MONTH, 1)
    months: list[date] = []

    for _ in range(_SCHOOL_YEAR_MONTHS):
        months.append(month)
        month = month_after(month)

    return months


class _Walk:
    """Lessons in order through the tariff rows; packages are used up in order."""

    def __init__(
        self,
        tariffs: Sequence[StudentTariff],
        payments: Sequence[StudentPayment],
        settle_rate: int,
    ) -> None:
        self.rows = sorted(tariffs, key=lambda row: (row.starts_on, row.id))
        self.settle_rate = settle_rate
        self.current = 0
        self.started_on: dict[int, date] = {0: self.rows[0].starts_on}
        # The day the last minute of a package row's packages went.
        self.ran_out_on: dict[int, date] = {}
        self.packages: dict[int, list[StudentPayment]] = defaultdict(list)
        self.left: dict[int, int] = {}
        # Payment ids by the month they pay.
        self.dated_months: dict[date, int] = {}
        # A fee starting when a package ends, by its row: its first month, once known.
        self.floating_months: dict[int, int] = {}
        self.lines: dict[HoursKindEnum, HoursLine] = {}
        # What each package, month's fee or hours paid ahead covered, by payment id.
        self.covered: dict[int, list[HistoryLesson]] = defaultdict(list)
        self.index_of = {row.id: index for index, row in enumerate(self.rows)}
        # Any lesson by the hour draws on them, those paid first first.
        self.ahead = sorted(
            (item for item in payments if item.kind == StudentPaymentKindEnum.AHEAD),
            key=lambda item: (item.paid_on, item.id),
        )
        self.ahead_left = {item.id: item.ahead_minutes or 0 for item in self.ahead}

        for payment in sorted(payments, key=lambda row: row.id):
            if payment.kind == StudentPaymentKindEnum.PACKAGE:
                if payment.tariff_id is not None and payment.package_hours is not None:
                    self.packages[payment.tariff_id].append(payment)
                    self.left[payment.id] = payment.package_hours * 60

            elif payment.kind == StudentPaymentKindEnum.MONTH:
                if payment.month is not None:
                    self.dated_months[payment.month] = payment.id

                elif payment.tariff_id is not None:
                    self.floating_months[payment.tariff_id] = payment.id

    def package_left(self, index: int) -> int:
        row = self.rows[index]

        return sum(self.left[package.id] for package in self.packages[row.id])

    # What was paid ahead under this hourly row or one before it: a change waits.
    def ahead_holding(self, index: int) -> int:
        return sum(
            self.ahead_left[item.id]
            for item in self.ahead
            if self.index_of.get(item.tariff_id or 0, len(self.rows)) <= index
        )

    def waits_for_end(self, index: int) -> bool:
        row = self.rows[index]

        if row.kind == TariffKindEnum.PACKAGE:
            return self.package_left(index) > 0

        if row.kind != TariffKindEnum.HOURLY or index + 1 >= len(self.rows):
            return False

        return (
            self.rows[index + 1].kind != TariffKindEnum.HOURLY
            and self.ahead_holding(index) > 0
        )

    def first_month(self, index: int) -> date:
        return self.started_on[index].replace(day=1)

    def month_payment(self, index: int, month: date) -> int | None:
        if month in self.dated_months:
            return self.dated_months[month]

        row = self.rows[index]

        if row.id in self.floating_months and month == self.first_month(index):
            return self.floating_months[row.id]

        return None

    def month_paid(self, index: int, month: date) -> bool:
        return self.month_payment(index, month) is not None

    def advance(self, day: date) -> None:
        while (
            self.current + 1 < len(self.rows)
            and self.rows[self.current + 1].starts_on <= day
        ):
            if self.waits_for_end(self.current):
                return

            row = self.rows[self.current]
            before = self.started_on[self.current]
            ran_out = self.ran_out_on.get(self.current, before)
            waited = row.kind == TariffKindEnum.PACKAGE or (
                row.kind == TariffKindEnum.HOURLY
                and self.rows[self.current + 1].kind != TariffKindEnum.HOURLY
            )
            self.current += 1
            self.started_on[self.current] = max(
                self.rows[self.current].starts_on,
                before,
                ran_out if waited else before,
            )

    def add(
        self,
        kind: HoursKindEnum,
        lesson: PupilLesson,
        minutes: int,
        cents_per_hour: int,
        tariff_id: int | None,
    ) -> None:
        line = self.lines.setdefault(kind, HoursLine(kind, cents_per_hour))

        # The newest rate is the one proposed for settling.
        line.cents_per_hour = cents_per_hour
        cents = _cents(minutes, cents_per_hour)
        line.parts.append(
            LessonPart(
                lesson.id,
                lesson.day,
                minutes,
                tariff_id,
                lesson.minutes,
                cents,
                opening=lesson.opening,
            )
        )
        line.cents += cents

    def take(self, lesson: PupilLesson, minutes: int) -> None:
        while minutes > 0:
            row = self.rows[self.current]

            if row.kind == TariffKindEnum.HOURLY:
                minutes = self._from_ahead(lesson, minutes)

                if minutes == 0:
                    return

                # The hours paid ahead ran out: a change waiting for them starts.
                index = self.current
                self.advance(lesson.day)

                if self.current != index:
                    continue

                self.add(
                    HoursKindEnum.HOURLY,
                    lesson,
                    minutes,
                    row.amount_cents,
                    row.id,
                )
                return

            if row.kind == TariffKindEnum.MONTHLY:
                paid = self.month_payment(self.current, lesson.day.replace(day=1))

                if paid is None:
                    self.add(
                        HoursKindEnum.OVER_FEE,
                        lesson,
                        minutes,
                        self.settle_rate,
                        row.id,
                    )
                else:
                    self.covered[paid].append(
                        HistoryLesson(
                            lesson.day,
                            minutes,
                            lesson.minutes,
                            opening=lesson.opening,
                        )
                    )

                return

            minutes = self._from_packages(row, lesson, minutes)

            if minutes == 0:
                return

            following = self.current + 1

            if (
                following < len(self.rows)
                and self.rows[following].starts_on <= lesson.day
            ):
                self.advance(lesson.day)
                continue

            self.add(
                HoursKindEnum.OVER_PACKAGE,
                lesson,
                minutes,
                self.settle_rate,
                row.id,
            )
            return

    def _from_packages(
        self,
        row: StudentTariff,
        lesson: PupilLesson,
        minutes: int,
    ) -> int:
        for package in self.packages[row.id]:
            left = self.left[package.id]

            if left == 0:
                continue

            used = min(left, minutes)
            self.left[package.id] = left - used
            minutes -= used
            self.covered[package.id].append(
                HistoryLesson(
                    lesson.day,
                    used,
                    lesson.minutes,
                    left_minutes=left - used,
                    exhausted=left == used,
                    before_payment=lesson.day < package.paid_on,
                    opening=lesson.opening,
                )
            )

            if self.left[package.id] == 0:
                self.ran_out_on[self.current] = lesson.day

            if minutes == 0:
                break

        return minutes


    def _from_ahead(self, lesson: PupilLesson, minutes: int) -> int:
        for payment in self.ahead:
            left = self.ahead_left[payment.id]

            if left == 0:
                continue

            used = min(left, minutes)
            self.ahead_left[payment.id] = left - used
            minutes -= used
            self.covered[payment.id].append(
                HistoryLesson(
                    lesson.day,
                    used,
                    lesson.minutes,
                    left_minutes=left - used,
                    exhausted=left == used,
                    before_payment=lesson.day < payment.paid_on,
                    opening=lesson.opening,
                )
            )

            if left == used:
                self.ran_out_on[self.current] = lesson.day

            if minutes == 0:
                break

        return minutes


def _walked(
    tariffs: Sequence[StudentTariff],
    payments: Sequence[StudentPayment],
    settled: dict[int, int],
    lessons: Sequence[PupilLesson],
    today: date,
    rates: PaymentRates,
) -> _Walk:
    walk = _Walk(tariffs, payments, rates.settle_cents)
    first_day = walk.rows[0].starts_on

    for lesson in sorted(lessons, key=lambda row: (row.day, row.start, row.id)):
        minutes = lesson.minutes - settled.get(lesson.id, 0)

        if minutes <= 0 or lesson.day < first_day:
            continue

        if lesson.weekend_online:
            walk.add(
                HoursKindEnum.WEEKEND_ONLINE,
                lesson,
                minutes,
                rates.weekend_online_cents,
                None,
            )
            continue

        walk.advance(lesson.day)
        walk.take(lesson, minutes)

    walk.advance(today)

    return walk


def payment_status(
    tariffs: Sequence[StudentTariff],
    payments: Sequence[StudentPayment],
    settled: dict[int, int],
    lessons: Sequence[PupilLesson],
    spans: Sequence[EnrolledSpan],
    today: date,
    rates: PaymentRates,
) -> PaymentStatus | None:
    """What a pupil has paid and what is left to pay or renew."""
    if not tariffs:
        return None

    walk = _walked(tariffs, payments, settled, lessons, today, rates)

    return _status(walk, payments, spans, today)


# When each tariff took over, as the lessons and the packages make it.
@dataclass(frozen=True)
class TariffTimeline:
    rows: list[StudentTariff]
    # By row id: the day it took over, or its own day while it has not yet.
    starts: dict[int, date]
    reached: set[int]
    # The days each package bought covered, by payment id.
    covered: dict[int, list[date]]


def tariff_timeline(
    tariffs: Sequence[StudentTariff],
    payments: Sequence[StudentPayment],
    settled: dict[int, int],
    lessons: Sequence[PupilLesson],
    today: date,
    rates: PaymentRates,
) -> TariffTimeline:
    walk = _walked(tariffs, payments, settled, lessons, today, rates)

    return TariffTimeline(
        rows=list(walk.rows),
        starts={
            row.id: walk.started_on.get(index, row.starts_on)
            for index, row in enumerate(walk.rows)
        },
        reached={walk.rows[index].id for index in walk.started_on},
        covered={
            payment_id: [lesson.day for lesson in covered]
            for payment_id, covered in walk.covered.items()
        },
    )


@dataclass(frozen=True)
class SettledLesson:
    payment_id: int
    lesson: PupilLesson
    minutes: int


@dataclass(frozen=True)
class HistoryRow:
    kind: HistoryKind
    # None while still to pay.
    payment: StudentPayment | None
    amount_cents: int
    # The newest first.
    lessons: list[HistoryLesson]
    package_hours: int | None = None
    month: date | None = None
    state: PackageState | None = None
    ahead_minutes: int | None = None

    @property
    def minutes(self) -> int:
        return sum(lesson.minutes for lesson in self.lessons)


def _newest_first(lessons: Sequence[HistoryLesson]) -> list[HistoryLesson]:
    return sorted(lessons, key=lambda lesson: lesson.day, reverse=True)


def _package_states(walk: _Walk) -> dict[int, PackageState]:
    states: dict[int, PackageState] = {}
    open_before = False

    for row in walk.rows:
        for package in walk.packages[row.id]:
            left = walk.left[package.id]
            total = (package.package_hours or 0) * 60

            if left == 0:
                states[package.id] = "ENDED"
            elif left < total:
                states[package.id] = "RUNNING"
            else:
                states[package.id] = "WAITING" if open_before else "UNUSED"

            open_before = open_before or left > 0

    return states


def _ahead_states(walk: _Walk) -> dict[int, PackageState]:
    states: dict[int, PackageState] = {}
    open_before = False

    for payment in walk.ahead:
        left = walk.ahead_left[payment.id]

        if left == 0:
            states[payment.id] = "ENDED"
        elif left < (payment.ahead_minutes or 0):
            states[payment.id] = "RUNNING"
        else:
            states[payment.id] = "WAITING" if open_before else "UNUSED"

        open_before = open_before or left > 0

    return states


# A fee starting when a package ends has no month until that package is over.
def _fee_month(walk: _Walk, payment: StudentPayment) -> date | None:
    if payment.month is not None:
        return payment.month

    for index, row in enumerate(walk.rows):
        if row.id == payment.tariff_id and index in walk.started_on:
            return walk.first_month(index)

    return None


def payment_history(
    tariffs: Sequence[StudentTariff],
    payments: Sequence[StudentPayment],
    settled: Sequence[SettledLesson],
    lessons: Sequence[PupilLesson],
    today: date,
    rates: PaymentRates,
) -> list[HistoryRow]:
    """Every payment with the lessons it covers, those still to pay first."""
    if not tariffs:
        return []

    minutes: dict[int, int] = defaultdict(int)

    for item in settled:
        minutes[item.lesson.id] += item.minutes

    walk = _walked(tariffs, payments, minutes, lessons, today, rates)
    states = _package_states(walk) | _ahead_states(walk)
    paid: list[HistoryRow] = []

    newest = sorted(payments, key=lambda row: (row.paid_on, row.id), reverse=True)

    for payment in newest:
        covered = _newest_first(walk.covered.get(payment.id, []))

        if payment.kind == StudentPaymentKindEnum.PACKAGE:
            if payment.id in states:
                paid.append(
                    HistoryRow(
                        "PACKAGE",
                        payment,
                        payment.amount_cents,
                        covered,
                        package_hours=payment.package_hours,
                        state=states[payment.id],
                    )
                )

        elif payment.kind == StudentPaymentKindEnum.AHEAD:
            paid.append(
                HistoryRow(
                    "AHEAD",
                    payment,
                    payment.amount_cents,
                    covered,
                    state=states.get(payment.id),
                    ahead_minutes=payment.ahead_minutes,
                )
            )

        elif payment.kind == StudentPaymentKindEnum.MONTH:
            month = _fee_month(walk, payment)
            paid.append(
                HistoryRow(
                    "MONTH",
                    payment,
                    payment.amount_cents,
                    covered,
                    month=month,
                    state="WAITING" if month is None else None,
                )
            )

        else:
            rate = payment.cents_per_hour or 0
            parts = [
                HistoryLesson(
                    item.lesson.day,
                    item.minutes,
                    item.lesson.minutes,
                    cents=_cents(item.minutes, rate),
                    opening=item.lesson.opening,
                )
                for item in settled
                if item.payment_id == payment.id
            ]
            paid.append(
                HistoryRow(
                    _HISTORY_KINDS[payment.hours_kind or HoursKindEnum.HOURLY],
                    payment,
                    payment.amount_cents,
                    _newest_first(parts),
                )
            )

    due = [
        HistoryRow(
            _HISTORY_KINDS[line.kind],
            None,
            line.cents,
            _newest_first(
                [
                    HistoryLesson(
                        part.day,
                        part.minutes,
                        part.lesson_minutes,
                        cents=part.cents,
                        opening=part.opening,
                    )
                    for part in line.parts
                ]
            ),
        )
        for line in walk.lines.values()
        if line.parts
    ]
    due.sort(key=lambda row: row.lessons[0].day, reverse=True)

    return due + paid


def _status(
    walk: _Walk,
    payments: Sequence[StudentPayment],
    spans: Sequence[EnrolledSpan],
    today: date,
) -> PaymentStatus:
    index = walk.current
    row = walk.rows[index]
    this_month = today.replace(day=1)
    lines = [walk.lines[kind] for kind in _LINE_ORDER if kind in walk.lines]
    amount = row.amount_cents
    hours = row.package_hours
    package: PackageStatus | None = None
    months: list[tuple[date, MonthState]] | None = None
    month_paid = False
    queued: Queued | None = None
    renew = False

    if row.kind == TariffKindEnum.PACKAGE:
        bought = walk.packages[row.id]
        running = [item for item in bought if walk.left[item.id] > 0]

        if bought:
            shown = running[0] if running else bought[-1]
            hours = shown.package_hours or 0
            amount = shown.amount_cents
            package = PackageStatus(
                hours=hours,
                amount_cents=amount,
                used_minutes=hours * 60 - walk.left[shown.id],
                ended_on=None if running else walk.ran_out_on.get(index),
            )

        renew = not running

        if len(running) > 1:
            queued = "PACKAGE"

    elif row.kind == TariffKindEnum.MONTHLY:
        fees = sorted(
            (
                item
                for item in payments
                if item.kind == StudentPaymentKindEnum.MONTH
                and item.tariff_id == row.id
            ),
            key=lambda item: (item.month or date.min, item.id),
        )

        if fees:
            amount = fees[-1].amount_cents

        month_paid = walk.month_paid(index, this_month)
        enrolled = enrolled_days(spans, this_month, month_after(this_month)) > 0
        renew = not month_paid and enrolled and this_month >= walk.first_month(index)
        months = [
            (
                month,
                "PAID"
                if walk.month_paid(index, month)
                else ("DUE" if month == this_month and renew else "NONE"),
            )
            for month in _school_year_months(today)
        ]

        if month_paid and walk.month_paid(index, month_after(this_month)):
            queued = "MONTH"

    queued_starts_on: date | None = None
    ahead: AheadStatus | None = None

    if row.kind == TariffKindEnum.HOURLY:
        bought = [item for item in walk.ahead if walk.ahead_left[item.id] > 0]
        total = sum(item.ahead_minutes or 0 for item in bought)

        if bought:
            left = sum(walk.ahead_left[item.id] for item in bought)
            ahead = AheadStatus(total_minutes=total, used_minutes=total - left)

    queued_tariff: StudentTariff | None = None

    if index + 1 < len(walk.rows):
        queued = "CHANGE"
        queued_tariff = walk.rows[index + 1]

        if not walk.waits_for_end(index):
            queued_starts_on = queued_tariff.starts_on

    state: State = "RENEW" if renew else ("DUE" if lines else "OK")

    return PaymentStatus(
        tariff=row,
        started_on=walk.started_on[index],
        amount_cents=amount,
        package_hours=hours,
        state=state,
        package=package,
        months=months,
        month_paid=month_paid,
        lines=lines,
        queued=queued,
        queued_starts_on=queued_starts_on,
        ahead=ahead,
        queued_tariff=queued_tariff,
    )


def _opening_lesson(day: date, band: str, minutes: int, online: bool) -> PupilLesson:
    return PupilLesson(
        id=band_unit(day, band),
        day=day,
        start=time(0),
        end=time(0),
        online=online,
        length=minutes,
        opening=True,
    )


def opening_lessons(start: PupilStart) -> list[PupilLesson]:
    """The set-up's minutes, walked as lessons of the day before money_from."""
    opening = start.opening

    if start.money_from is None or opening is None or opening.confirmed_at is None:
        return []

    day = day_before(start.money_from)
    lessons: list[PupilLesson] = []
    presence = opening.used_minutes + opening.due_minutes

    if presence:
        lessons.append(_opening_lesson(day, _OPENING_PRESENCE, presence, False))

    if opening.weekend_minutes:
        lessons.append(
            _opening_lesson(day, _OPENING_ONLINE, opening.weekend_minutes, True),
        )

    return lessons


# Money is worked out from money_from on: before it, the set-up speaks.
def counted_lessons(
    lessons: Sequence[PupilLesson],
    start: PupilStart,
) -> list[PupilLesson]:
    first = start.money_from
    kept = [lesson for lesson in lessons if first is None or lesson.day >= first]

    return sorted([*opening_lessons(start), *kept], key=lambda row: (row.day, row.id))


def opening_state(start: PupilStart) -> OpeningState | None:
    opening = start.opening

    if opening is None or start.money_from is None:
        return None

    if opening.confirmed_at is not None:
        return "DONE"

    # Left the lists by not collaborating: nothing to wait for.
    return "PENDING" if start.pending else None


# Confirmed bands only: hours count once an admin has checked them.
async def pupil_lessons(
    db: AsyncSession,
    tax_code: str,
    since: date,
    now: datetime,
) -> list[PupilLesson]:
    """The pupil's confirmed bands, one each, from since up to today."""
    start = await pupil_start(db, tax_code)

    return await _pupil_lessons(db, tax_code, since, now, start)


async def _pupil_lessons(
    db: AsyncSession,
    tax_code: str,
    since: date,
    now: datetime,
    account_start: PupilStart,
) -> list[PupilLesson]:
    rows = await db.execute(
        select(
            StudentConfirmedHours.date,
            StudentConfirmedHours.band,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
            StudentConfirmedHours.mode,
        ).where(
            StudentConfirmedHours.student_tax_code == tax_code,
            StudentConfirmedHours.date >= since,
            StudentConfirmedHours.date <= now.date(),
        ),
    )

    stretches: dict[tuple[date, str], list[tuple[time, time, str]]] = defaultdict(list)

    for day, band, start, end, mode in rows.tuples():
        stretches[(day, band)].append((start, end, mode))

    return counted_lessons(
        [
            unit_lesson(day, band, listed)
            for (day, band), listed in sorted(stretches.items())
        ],
        account_start,
    )


def unit_lesson(
    day: date,
    band: str,
    stretches: Sequence[tuple[time, time, str]],
) -> PupilLesson:
    return PupilLesson(
        id=band_unit(day, band),
        day=day,
        start=min(start for start, _, _ in stretches),
        end=max(end for _, end, _ in stretches),
        online=all(mode == _ONLINE for _, _, mode in stretches),
        length=sum(
            minutes_of(end) - minutes_of(start) for start, end, _ in stretches
        ),
    )


async def school_level(db: AsyncSession, tax_code: str) -> EducationLevelEnum | None:
    """The level of the latest school year on record."""
    return await db.scalar(
        select(StudyProgram.level)
        .join(SchoolEnrollment, SchoolEnrollment.study_program_id == StudyProgram.id)
        .where(SchoolEnrollment.student_tax_code == tax_code)
        .order_by(SchoolEnrollment.start_year.desc())
        .limit(1),
    )


# Settled, then taken out of its band: the payment still names it.
def _gone_lesson(day: date, band: str, minutes: int) -> PupilLesson:
    return PupilLesson(
        id=band_unit(day, band),
        day=day,
        start=time(0),
        end=time(0),
        online=False,
        length=minutes,
    )


# A band reopened and confirmed again keeps what was settled of it.
async def settled_lessons(
    db: AsyncSession,
    tax_code: str,
    lessons: Sequence[PupilLesson],
) -> list[SettledLesson]:
    rows = await db.execute(
        select(
            StudentPaymentBand.payment_id,
            StudentPaymentBand.date,
            StudentPaymentBand.band,
            StudentPaymentBand.minutes,
        )
        .join(StudentPayment, StudentPayment.id == StudentPaymentBand.payment_id)
        .where(StudentPayment.student_tax_code == tax_code),
    )
    by_unit = {lesson.id: lesson for lesson in lessons}
    settled: list[SettledLesson] = []

    for payment_id, day, band, minutes in rows.tuples():
        lesson = by_unit.get(band_unit(day, band)) or _gone_lesson(day, band, minutes)
        settled.append(SettledLesson(payment_id, lesson, minutes))

    return settled


@dataclass(frozen=True)
class StudentPayments:
    status: PaymentStatus | None
    level: EducationLevelEnum | None
    # The newest, which the summary shows as the way the pupil pays.
    last_payment: StudentPayment | None
    rates: PaymentRates
    history: list[HistoryRow] = field(default_factory=list)
    opening: OpeningState | None = None
    # The day the initial set-up describes.
    opening_day: date | None = None


async def student_payment_status(
    db: AsyncSession,
    tax_code: str,
    now: datetime,
) -> StudentPayments:
    tariffs = list(
        await db.scalars(
            select(StudentTariff).where(StudentTariff.student_tax_code == tax_code),
        )
    )
    payments = list(
        await db.scalars(
            select(StudentPayment).where(StudentPayment.student_tax_code == tax_code),
        )
    )
    level = await school_level(db, tax_code)
    rates = await payment_rates(db, level)
    last = max(payments, key=lambda row: (row.paid_on, row.id), default=None)
    today = now.date()
    start = await pupil_start(db, tax_code)

    opening = opening_state(start)
    opening_day = (
        None
        if opening is None or start.money_from is None
        else day_before(start.money_from)
    )

    if not tariffs:
        return StudentPayments(
            None,
            level,
            last,
            rates,
            opening=opening,
            opening_day=opening_day,
        )

    since = min(row.starts_on for row in tariffs)
    lessons = await _pupil_lessons(db, tax_code, since, now, start)
    spans = (await enrolled_spans(db, [tax_code])).get(tax_code, [])
    settled = await settled_lessons(db, tax_code, lessons)
    minutes: dict[int, int] = defaultdict(int)

    for item in settled:
        minutes[item.lesson.id] += item.minutes

    return StudentPayments(
        payment_status(tariffs, payments, minutes, lessons, spans, today, rates),
        level,
        last,
        rates,
        payment_history(tariffs, payments, settled, lessons, today, rates),
        opening,
        opening_day,
    )


# What the payment walk reads of one pupil.
@dataclass(frozen=True)
class PupilBooks:
    tariffs: list[StudentTariff]
    payments: list[StudentPayment]
    lessons: list[PupilLesson]
    settled: list[SettledLesson]
    rates: PaymentRates
    spans: list[EnrolledSpan]
    # The initial set-up is still to do: its money is not known yet.
    pending: bool = False
    money_from: date | None = None

    @property
    def settled_minutes(self) -> dict[int, int]:
        minutes: dict[int, int] = defaultdict(int)

        for item in self.settled:
            minutes[item.lesson.id] += item.minutes

        return dict(minutes)

    def status(self, today: date) -> PaymentStatus | None:
        return payment_status(
            self.tariffs,
            self.payments,
            self.settled_minutes,
            self.lessons,
            self.spans,
            today,
            self.rates,
        )


# The same reads as student_payment_status, once for all the pupils: the pages
# listing everybody would otherwise ask the database pupil by pupil.
async def pupil_books(
    db: AsyncSession,
    tax_codes: Sequence[str],
    now: datetime,
) -> dict[str, PupilBooks]:
    codes = list(dict.fromkeys(tax_codes))

    if not codes:
        return {}

    tariffs: dict[str, list[StudentTariff]] = defaultdict(list)

    for row in await db.scalars(
        select(StudentTariff).where(StudentTariff.student_tax_code.in_(codes)),
    ):
        tariffs[row.student_tax_code].append(row)

    payments: dict[str, list[StudentPayment]] = defaultdict(list)

    for payment in await db.scalars(
        select(StudentPayment).where(StudentPayment.student_tax_code.in_(codes)),
    ):
        payments[payment.student_tax_code].append(payment)

    # The latest school year on record says the level, as school_level.
    levels: dict[str, EducationLevelEnum] = {}
    school_years = await db.execute(
        select(SchoolEnrollment.student_tax_code, StudyProgram.level)
        .join(StudyProgram, SchoolEnrollment.study_program_id == StudyProgram.id)
        .where(SchoolEnrollment.student_tax_code.in_(codes))
        .order_by(
            SchoolEnrollment.student_tax_code,
            SchoolEnrollment.start_year.desc(),
        ),
    )

    for tax_code, level in school_years.tuples():
        levels.setdefault(tax_code, level)

    standard = {row.level: row for row in await standard_tariffs(db)}

    hours = await db.execute(
        select(
            StudentConfirmedHours.student_tax_code,
            StudentConfirmedHours.date,
            StudentConfirmedHours.band,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
            StudentConfirmedHours.mode,
        ).where(
            StudentConfirmedHours.student_tax_code.in_(codes),
            StudentConfirmedHours.date <= now.date(),
        ),
    )
    stretches: dict[str, dict[tuple[date, str], list[tuple[time, time, str]]]] = (
        defaultdict(lambda: defaultdict(list))
    )

    for tax_code, day, band, start, end, mode in hours.tuples():
        stretches[tax_code][(day, band)].append((start, end, mode))

    bands = await db.execute(
        select(
            StudentPayment.student_tax_code,
            StudentPaymentBand.payment_id,
            StudentPaymentBand.date,
            StudentPaymentBand.band,
            StudentPaymentBand.minutes,
        )
        .join(StudentPayment, StudentPayment.id == StudentPaymentBand.payment_id)
        .where(StudentPayment.student_tax_code.in_(codes)),
    )
    settled_bands: dict[str, list[tuple[int, date, str, int]]] = defaultdict(list)

    for tax_code, payment_id, day, band, minutes in bands.tuples():
        settled_bands[tax_code].append((payment_id, day, band, minutes))

    spans = await enrolled_spans(db, codes)
    starts = await pupil_starts(db, codes)
    books: dict[str, PupilBooks] = {}

    for tax_code in codes:
        own = tariffs.get(tax_code, [])
        rates = rates_of(standard.get(levels.get(tax_code)))
        start = starts[tax_code]

        if not own:
            books[tax_code] = PupilBooks(
                [],
                payments.get(tax_code, []),
                [],
                [],
                rates,
                [],
                start.pending,
                start.money_from,
            )
            continue

        since = min(row.starts_on for row in own)
        lessons = counted_lessons(
            [
                unit_lesson(day, band, listed)
                for (day, band), listed in sorted(stretches[tax_code].items())
                if day >= since
            ],
            start,
        )
        by_unit = {lesson.id: lesson for lesson in lessons}
        settled = [
            SettledLesson(
                payment_id,
                by_unit.get(band_unit(day, band)) or _gone_lesson(day, band, minutes),
                minutes,
            )
            for payment_id, day, band, minutes in settled_bands.get(tax_code, [])
        ]
        books[tax_code] = PupilBooks(
            own,
            payments.get(tax_code, []),
            lessons,
            settled,
            rates,
            spans.get(tax_code, []),
            start.pending,
            start.money_from,
        )

    return books


SituationKind = Literal[
    "NONE",
    "PACKAGE_LEFT",
    "PACKAGE_ENDED",
    "MONTH_PAID",
    "MONTH_UNPAID",
    "SETTLE",
    "AHEAD_LEFT",
    "AHEAD_ENDED",
    "PENDING",
]


# A pupil's account as the daily summary reads it, band after band.
@dataclass(frozen=True)
class PupilAccount:
    tariffs: list[StudentTariff]
    payments: list[StudentPayment]
    lessons: list[PupilLesson]
    settled: dict[int, int]
    rates: PaymentRates
    start: PupilStart = field(default_factory=PupilStart)


# Where a pupil stands right after one band, with that band's hours.
@dataclass(frozen=True)
class BandSituation:
    kind: SituationKind
    tariff_kind: TariffKindEnum | None = None
    # By the hour, the package or the month, as the tariff is paid.
    tariff_cents: int | None = None
    package_hours: int | None = None
    # Left of the package or of the hours paid ahead; once they ran out, those
    # of this band they did not cover.
    minutes: int = 0
    # The package running from this band is a renewal, already paid.
    renewed: bool = False
    # What this band's hours add to what is left to settle.
    cost_cents: int = 0


async def pupil_account(
    db: AsyncSession,
    tax_code: str,
    now: datetime,
) -> PupilAccount:
    tariffs = list(
        await db.scalars(
            select(StudentTariff).where(StudentTariff.student_tax_code == tax_code),
        )
    )
    payments = list(
        await db.scalars(
            select(StudentPayment).where(StudentPayment.student_tax_code == tax_code),
        )
    )
    rates = await payment_rates(db, await school_level(db, tax_code))
    start = await pupil_start(db, tax_code)

    if not tariffs:
        return PupilAccount(tariffs, payments, [], {}, rates, start)

    since = min(row.starts_on for row in tariffs)
    lessons = await _pupil_lessons(db, tax_code, since, now, start)
    settled: dict[int, int] = defaultdict(int)

    for item in await settled_lessons(db, tax_code, lessons):
        settled[item.lesson.id] += item.minutes

    return PupilAccount(tariffs, payments, lessons, dict(settled), rates, start)


def _running_package(walk: _Walk, row: StudentTariff) -> StudentPayment | None:
    return next(
        (item for item in walk.packages[row.id] if walk.left[item.id] > 0),
        None,
    )


def band_situation(
    account: PupilAccount,
    day: date,
    band: str,
    stretches: Sequence[tuple[time, time]],
    online: bool,
) -> BandSituation:
    first = account.start.money_from

    if first is not None and day < first:
        return BandSituation("NONE")

    if account.start.pending:
        return BandSituation("PENDING")

    if not account.tariffs:
        return BandSituation("NONE")

    unit = band_unit(day, band)
    before = [lesson for lesson in account.lessons if lesson.id < unit]
    mode = _ONLINE if online else "presence"
    here = (
        unit_lesson(day, band, [(start, end, mode) for start, end in stretches])
        if stretches
        else None
    )

    def walked(lessons: list[PupilLesson]) -> _Walk:
        return _walked(
            account.tariffs,
            account.payments,
            account.settled,
            lessons,
            day,
            account.rates,
        )

    prior = walked(before)
    after = walked([*before, here] if here is not None else before)

    if day < after.rows[0].starts_on:
        return BandSituation("NONE")

    row = after.rows[after.current]
    mine = [
        (line.kind, part)
        for line in after.lines.values()
        for part in line.parts
        if part.lesson_id == unit
    ]
    cost = sum(part.cents for _, part in mine)

    def uncovered(kind: HoursKindEnum) -> int:
        return sum(part.minutes for line_kind, part in mine if line_kind == kind)

    base = BandSituation(
        "SETTLE",
        tariff_kind=row.kind,
        tariff_cents=row.amount_cents,
        package_hours=row.package_hours,
        cost_cents=cost,
    )

    if here is not None and here.weekend_online:
        return base

    if row.kind == TariffKindEnum.PACKAGE:
        running = _running_package(after, row)
        bought = after.packages[row.id]
        shown = running or (bought[-1] if bought else None)

        if shown is not None:
            base = replace(
                base,
                tariff_cents=shown.amount_cents,
                package_hours=shown.package_hours,
            )

        if running is None:
            return replace(
                base,
                kind="PACKAGE_ENDED",
                minutes=uncovered(HoursKindEnum.OVER_PACKAGE),
            )

        total = (running.package_hours or 0) * 60
        begun_here = prior.left.get(running.id) == total > after.left[running.id]
        used_before = any(
            after.left[item.id] < (item.package_hours or 0) * 60
            for packages in after.packages.values()
            for item in packages
            if item.id != running.id
        )

        return replace(
            base,
            kind="PACKAGE_LEFT",
            minutes=after.left[running.id],
            renewed=begun_here and used_before,
        )

    if row.kind == TariffKindEnum.MONTHLY:
        paid = after.month_paid(after.current, day.replace(day=1))

        return replace(base, kind="MONTH_PAID" if paid else "MONTH_UNPAID")

    ahead_before = sum(prior.ahead_left.values())
    ahead_after = sum(after.ahead_left.values())

    if ahead_after > 0:
        return replace(base, kind="AHEAD_LEFT", minutes=ahead_after)

    if ahead_before > 0:
        return replace(
            base,
            kind="AHEAD_ENDED",
            minutes=uncovered(HoursKindEnum.HOURLY),
        )

    return base


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


async def _kind_disabled(db: AsyncSession, tax_code: str) -> HTTPException:
    gender = await PersonRepository(db).gender(tax_code)

    return _bad_request(_KIND_DISABLED_ERRORS[gender].for_request())


def _payment(
    tax_code: str,
    data: PaymentData,
    today: date,
    **fields: object,
) -> StudentPayment:
    if data.paid_on > today:
        raise _bad_request(_PAID_IN_FUTURE_ERROR.for_request())

    return StudentPayment(
        student_tax_code=tax_code,
        paid_on=data.paid_on,
        payment_method=data.payment_method,
        payment_method_other=(
            data.payment_method_other
            if data.payment_method == PaymentMethodEnum.OTHER
            else None
        ),
        **fields,
    )


async def _running(db: AsyncSession, tax_code: str, now: datetime) -> StudentPayments:
    payments = await student_payment_status(db, tax_code, now)

    if payments.status is None:
        gender = await PersonRepository(db).gender(tax_code)

        raise _bad_request(_NO_TARIFF_ERRORS[gender].for_request())

    return payments


def _refuse_queued(current: PaymentStatus) -> None:
    if current.queued == "CHANGE":
        raise _conflict(_ALREADY_CHANGED_ERROR.for_request())

    if current.queued is not None:
        raise _conflict(_ALREADY_RENEWED_ERROR.for_request())


def _month_to_buy(current: PaymentStatus, today: date, next_month: bool) -> date:
    this_month = today.replace(day=1)

    if next_month:
        return month_after(this_month)

    if current.month_paid:
        raise _bad_request(_MONTH_PAID_ERROR.for_request())

    return this_month


async def renew(
    db: AsyncSession,
    tax_code: str,
    data: RenewalData,
    now: datetime,
) -> StudentPayment:
    """A package or a month bought again: renewing is paying."""
    current = (await _running(db, tax_code, now)).status
    assert current is not None
    _refuse_queued(current)
    today = now.date()
    row = current.tariff

    if row.kind == TariffKindEnum.HOURLY:
        raise _bad_request(_HOURLY_NOT_RENEWED_ERROR.for_request())

    package = row.kind == TariffKindEnum.PACKAGE

    if package != (data.package_hours is not None):
        raise _bad_request(_PACKAGE_HOURS_ERROR.for_request())

    if package:
        payment = _payment(
            tax_code,
            data.payment,
            today,
            kind=StudentPaymentKindEnum.PACKAGE,
            tariff_id=row.id,
            package_hours=data.package_hours,
            amount_cents=data.amount_cents,
        )
    else:
        payment = _payment(
            tax_code,
            data.payment,
            today,
            kind=StudentPaymentKindEnum.MONTH,
            tariff_id=row.id,
            month=_month_to_buy(current, today, current.month_paid),
            amount_cents=data.amount_cents,
        )

    db.add(payment)
    await db.flush()

    return payment


def _starts_on(
    current: PaymentStatus,
    data: TariffChangeData,
    today: date,
    accounts_from: date | None = None,
) -> tuple[date, date | None]:
    """The new row's day and, for a fee, the month paid; null: at the package's end."""
    row = current.tariff
    month: date | None = None
    paid_ahead = current.ahead is not None and data.kind != TariffKindEnum.HOURLY

    if paid_ahead:
        return max(today, row.starts_on), None

    if data.kind == TariffKindEnum.MONTHLY or row.kind == TariffKindEnum.MONTHLY:
        package_running = current.package is not None and current.package.running

        if row.kind == TariffKindEnum.PACKAGE and package_running:
            return max(today, row.starts_on), None

        month = _month_to_buy(current, today, data.next_month)

        return max(month, row.starts_on), month

    if row.kind == TariffKindEnum.PACKAGE:
        return max(today, row.starts_on), None

    if data.starts_on is None:
        raise _bad_request(_DAY_REQUIRED_ERROR.for_request())

    if data.starts_on < current.started_on:
        raise _bad_request(_DAY_TOO_EARLY_ERROR.for_request())

    if accounts_from is not None and data.starts_on < accounts_from:
        raise _bad_request(_BEFORE_ACCOUNTS_ERROR.for_request())

    if data.starts_on > today + _LONGEST_WAIT:
        raise _bad_request(_DAY_TOO_FAR_ERROR.for_request())

    return data.starts_on, None


# A pupil on file without one: from the day given, a package or fee still to buy.
async def _first_tariff(
    db: AsyncSession,
    tax_code: str,
    data: TariffChangeData,
    level: EducationLevelEnum | None,
    today: date,
) -> StudentTariff:
    if data.kind not in enabled_kinds(await standard_tariff(db, level)):
        raise await _kind_disabled(db, tax_code)

    starts_on = data.starts_on or today

    if starts_on > today:
        raise _bad_request(_DAY_IN_FUTURE_ERROR.for_request())

    tariff = StudentTariff(
        student_tax_code=tax_code,
        kind=data.kind,
        starts_on=starts_on,
        amount_cents=data.amount_cents,
        package_hours=data.package_hours,
    )
    db.add(tariff)
    await db.flush()

    return tariff


async def change_tariff(
    db: AsyncSession,
    tax_code: str,
    data: TariffChangeData,
    now: datetime,
) -> StudentTariff:
    """Another kind of tariff, or another hourly rate; a package or fee is paid now."""
    payments = await student_payment_status(db, tax_code, now)
    current = payments.status

    if current is None:
        return await _first_tariff(db, tax_code, data, payments.level, now.date())

    _refuse_queued(current)
    today = now.date()
    row = current.tariff

    # Whoever has a kind turned off keeps it, its rate changes included.
    standard = await standard_tariff(db, payments.level)

    if data.kind != row.kind and data.kind not in enabled_kinds(standard):
        raise await _kind_disabled(db, tax_code)

    if data.kind == row.kind and data.kind != TariffKindEnum.HOURLY:
        raise _bad_request(_SAME_KIND_ERROR.for_request())

    starts_on, month = _starts_on(current, data, today, await money_from(db))
    paid = data.kind != TariffKindEnum.HOURLY

    if paid and data.payment is None:
        raise _bad_request(_PAYMENT_REQUIRED_ERROR.for_request())

    tariff = StudentTariff(
        student_tax_code=tax_code,
        kind=data.kind,
        starts_on=starts_on,
        amount_cents=data.amount_cents,
        package_hours=data.package_hours,
    )
    db.add(tariff)
    await db.flush()

    if data.payment is not None and paid:
        db.add(
            _payment(
                tax_code,
                data.payment,
                today,
                kind=(
                    StudentPaymentKindEnum.PACKAGE
                    if data.kind == TariffKindEnum.PACKAGE
                    else StudentPaymentKindEnum.MONTH
                ),
                tariff_id=tariff.id,
                month=month if data.kind == TariffKindEnum.MONTHLY else None,
                package_hours=data.package_hours,
                amount_cents=data.amount_cents,
            )
        )
        await db.flush()

    return tariff


async def settle(
    db: AsyncSession,
    tax_code: str,
    data: SettlementData,
    now: datetime,
) -> StudentPayment:
    """A line of hours paid by the hour, whole or the days chosen of it."""
    payments = await _running(db, tax_code, now)
    current = payments.status
    assert current is not None
    line = current.line(data.hours_kind)

    if line is None or line.minutes == 0:
        raise _bad_request(_NOTHING_TO_SETTLE_ERROR.for_request())

    if data.expected_minutes is not None and data.expected_minutes != line.minutes:
        raise _conflict(_LINE_CHANGED_ERROR.for_request())

    chosen = set(data.days) if data.days is not None else None
    parts = [
        part for part in line.parts if chosen is None or part.day in chosen
    ]

    # A day no longer in the line: the window read another state.
    if chosen is not None and {part.day for part in parts} != chosen:
        raise _conflict(_LINE_CHANGED_ERROR.for_request())

    weekend = data.hours_kind == HoursKindEnum.WEEKEND_ONLINE
    rate = payments.rates.weekend_online_cents if weekend else data.cents_per_hour
    minutes_settled = sum(part.minutes for part in parts)
    # Mixed hourly rates keep their own sum unless another rate is asked.
    amount = (
        sum(part.cents for part in parts)
        if rate == line.cents_per_hour
        else _cents(minutes_settled, rate)
    )
    payment = _payment(
        tax_code,
        data.payment,
        now.date(),
        kind=StudentPaymentKindEnum.HOURS,
        hours_kind=data.hours_kind,
        cents_per_hour=rate,
        amount_cents=max(amount, 1),
    )
    db.add(payment)
    await db.flush()

    minutes: dict[int, int] = defaultdict(int)

    for part in parts:
        minutes[part.lesson_id] += part.minutes

    for unit, total in minutes.items():
        day, band = unit_band(unit)
        db.add(
            StudentPaymentBand(
                payment_id=payment.id,
                date=day,
                band=band,
                minutes=total,
            )
        )

    await db.flush()

    return payment


async def pay_ahead(
    db: AsyncSession,
    tax_code: str,
    data: AheadData,
    now: datetime,
) -> StudentPayment:
    """Hours paid before they are done; added to any still left."""
    current = (await _running(db, tax_code, now)).status
    assert current is not None
    row = current.tariff

    if row.kind != TariffKindEnum.HOURLY:
        raise _bad_request(_AHEAD_HOURLY_ONLY_ERROR.for_request())

    if current.queued == "CHANGE":
        raise _conflict(_ALREADY_CHANGED_ERROR.for_request())

    payment = _payment(
        tax_code,
        data.payment,
        now.date(),
        kind=StudentPaymentKindEnum.AHEAD,
        tariff_id=row.id,
        ahead_minutes=data.minutes,
        cents_per_hour=data.cents_per_hour,
        amount_cents=max(_cents(data.minutes, data.cents_per_hour), 1),
    )
    db.add(payment)
    await db.flush()

    return payment


async def cancel_payment(db: AsyncSession, tax_code: str, payment_id: int) -> None:
    """A payment taken back: the hours it covered or settled are to settle again."""
    payment = await db.get(StudentPayment, payment_id)

    if payment is None or payment.student_tax_code != tax_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PAYMENT_NOT_FOUND_ERROR.for_request(),
        )

    await db.execute(
        delete(StudentPaymentBand).where(StudentPaymentBand.payment_id == payment.id),
    )
    await db.delete(payment)
    await db.flush()


async def current_tariff_kinds(
    db: AsyncSession,
    tax_codes: Sequence[str],
    today: date,
) -> dict[str, TariffKindEnum]:
    """The kind in force today; a tariff starting later does not count yet."""
    if not tax_codes:
        return {}

    rows = await db.execute(
        select(StudentTariff.student_tax_code, StudentTariff.kind)
        .where(
            StudentTariff.student_tax_code.in_(tax_codes),
            StudentTariff.starts_on <= today,
        )
        .order_by(
            StudentTariff.student_tax_code,
            StudentTariff.starts_on,
            StudentTariff.id,
        ),
    )

    return {row.student_tax_code: row.kind for row in rows}


async def first_tariffs(
    db: AsyncSession,
    tariff: StudentTariffData | None,
    study_program_id: int | None,
    today: date,
) -> list[StudentTariff]:
    """A new pupil's tariff, from today, of a kind turned on for the level."""
    if tariff is None:
        return []

    if study_program_id is not None:
        level = await db.scalar(
            select(StudyProgram.level).where(StudyProgram.id == study_program_id),
        )

        # The pupil is not named here, so the sentence stays masculine.
        if tariff.kind not in enabled_kinds(await standard_tariff(db, level)):
            raise _bad_request(_KIND_DISABLED_ERRORS[GenderEnum.M].for_request())

    return [
        StudentTariff(
            kind=tariff.kind,
            starts_on=today,
            amount_cents=tariff.amount_cents,
            package_hours=tariff.package_hours,
        )
    ]
