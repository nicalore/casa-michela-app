from collections import defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import TimeBandEnum, band_bounds
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.person import GenderEnum, Person
from app.models.presence import Presence
from app.models.student import Student
from app.models.student_hours import (
    StudentConfirmedBand,
    StudentConfirmedHours,
    StudentHoursCorrection,
)
from app.repositories.person_repository import PersonRepository
from app.services.bilingual import Bilingual
from app.services.enrollment_spans import enrolled_on, hours_spans, is_enrolled_on
from app.services.student_payments import (
    BandSituation,
    PupilAccount,
    band_situation,
    pupil_account,
)
from app.services.teacher_hours import (
    STEP_MINUTES,
    BandStatus,
    assert_band_begun,
    confirm_from_error,
)
from app.services.worked_hours import (
    ONLINE,
    PRESENCE,
    Span,
    merge,
    minutes_of,
    published_pairs,
    span_minutes,
    time_of,
)

_CONFIRMED_ERROR: Final[Bilingual] = Bilingual(
    "La fascia è confermata: premi «MODIFICA ORE» per correggerla.",
    "The time slot is confirmed: press “EDIT HOURS” to correct it.",
)
_NOT_CONFIRMED_ERROR: Final[Bilingual] = Bilingual(
    "La fascia non è confermata.",
    "The time slot is not confirmed.",
)
_ALREADY_CONFIRMED_ERROR: Final[Bilingual] = Bilingual(
    "La fascia è già confermata.",
    "The time slot is already confirmed.",
)
_NOTHING_TO_CONFIRM_ERROR: Final[Bilingual] = Bilingual(
    "Non ci sono ore da confermare.",
    "There are no hours to confirm.",
)
_NOT_IN_BAND_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Lo studente non è nel riepilogo di questa fascia.",
        "The student is not in this time slot's summary.",
    ),
    GenderEnum.F: Bilingual(
        "La studentessa non è nel riepilogo di questa fascia.",
        "The student is not in this time slot's summary.",
    ),
}
_NOT_ARRIVED_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Le ore dello studente si correggono quando finisce la sua ultima lezione.",
        "The student's hours can be corrected once their last lesson ends.",
    ),
    GenderEnum.F: Bilingual(
        "Le ore della studentessa si correggono quando finisce la sua ultima lezione.",
        "The student's hours can be corrected once their last lesson ends.",
    ),
}
_NOT_ENROLLED_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "In questo giorno non risulta iscritto.",
        "Not enrolled on this day.",
    ),
    GenderEnum.F: Bilingual(
        "In questo giorno non risulta iscritta.",
        "Not enrolled on this day.",
    ),
}
_ALREADY_IN_BAND_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Lo studente è già nel riepilogo di questa fascia.",
        "The student is already in this time slot's summary.",
    ),
    GenderEnum.F: Bilingual(
        "La studentessa è già nel riepilogo di questa fascia.",
        "The student is already in this time slot's summary.",
    ),
}
_STUDENT_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Studente non trovato",
    "Student not found",
)
_NO_HOURS_ERROR: Final[Bilingual] = Bilingual(
    "Indica almeno un orario.",
    "Enter at least one time.",
)
_BAD_TIME_ERROR: Final[Bilingual] = Bilingual(
    "Gli orari vanno a quarti d'ora, dentro la fascia.",
    "Times go by quarter hours, within the time slot.",
)
_OVERLAP_ERROR: Final[Bilingual] = Bilingual(
    "Gli orari non possono sovrapporsi.",
    "Times cannot overlap.",
)

# A pupil's lesson in the calendar: its mode and times.
PupilStretch = tuple[str, time, time]


# Left out of a partial update: not the same as None, which clears.
class _Unset:
    pass


UNSET: Final[_Unset] = _Unset()


@dataclass(frozen=True)
class PupilRow:
    tax_code: str
    first_name: str
    last_name: str
    mode: str
    absent: bool
    added: bool
    planned: list[Span] | None
    work: list[Span]
    situation: BandSituation

    @property
    def minutes(self) -> int:
        return span_minutes(self.work)


@dataclass(frozen=True)
class PupilBandSummary:
    day: date
    band: str
    status: BandStatus
    rows: list[PupilRow]
    # Pupils whose last lesson is still to end, named.
    waiting: list[str]
    # The same, for whoever adds a pupil: they cannot be added twice.
    waiting_tax_codes: list[str]
    first_end: int | None
    last_end: int | None
    # Today only: when the next row comes in.
    next_arrival: int | None
    reopened: bool


def _span_of(start: str, end: str) -> Span:
    return (minutes_of(_time(start)), minutes_of(_time(end)))


def _time(text: str) -> time:
    hours, minutes = text.split(":")

    return time_of(int(hours) * 60 + int(minutes))


def _dump(spans: Iterable[Span]) -> list[list[str]]:
    return [
        [time_of(start).strftime("%H:%M"), time_of(end).strftime("%H:%M")]
        for start, end in spans
    ]


def _load(work: list[list[str]]) -> list[Span]:
    return [_span_of(start, end) for start, end in work]


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def _minute_of(moment: datetime) -> int:
    return moment.hour * 60 + moment.minute


def _arrived(day: date, end: int, now: datetime) -> bool:
    return day < now.date() or (day == now.date() and end <= _minute_of(now))


# A gap between two lessons is not a lesson: stretches stay apart.
def _planned_of(stretches: Sequence[PupilStretch]) -> tuple[str, list[Span]]:
    online = all(mode == ONLINE for mode, _, _ in stretches)
    spans = merge(
        (minutes_of(start), minutes_of(end)) for _, start, end in stretches
    )

    return (ONLINE if online else PRESENCE), spans


# What the published calendar says of a band, pupil by pupil.
async def pupil_band_rows(
    db: AsyncSession,
    day: date,
    band: str,
) -> dict[str, list[PupilStretch]]:
    if (day, band) not in await published_pairs(db, day, day + timedelta(days=1)):
        return {}

    rows = await db.execute(
        select(
            Presence.student_tax_code,
            Lesson.id,
            Lesson.mode,
            Lesson.start_time,
            Lesson.end_time,
        )
        .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
        .where(Lesson.date == day, Lesson.band == band),
    )

    seen: set[tuple[str, int]] = set()
    by_pupil: dict[str, list[PupilStretch]] = defaultdict(list)

    # A lesson shared by two of the pupil's subjects counts once.
    for tax_code, lesson_id, mode, start, end in rows.tuples():
        if (tax_code, lesson_id) in seen:
            continue

        seen.add((tax_code, lesson_id))
        by_pupil[tax_code].append((mode, start, end))

    return dict(by_pupil)


# When each published band's last pupil lesson ends, over a stretch of days.
async def pupil_band_ends(
    db: AsyncSession,
    start: date,
    end: date,
) -> dict[tuple[date, str], time]:
    published = await published_pairs(db, start, end)
    rows = (
        await db.execute(
            select(
                Presence.student_tax_code,
                Lesson.date,
                Lesson.band,
                func.max(Lesson.end_time),
            )
            .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
            .join(Booking, Booking.id == LessonBooking.booking_id)
            .join(Presence, Presence.id == Booking.presence_id)
            .where(Lesson.date >= start, Lesson.date < end)
            .group_by(Presence.student_tax_code, Lesson.date, Lesson.band),
        )
    ).tuples().all()
    # As the daily summary: nobody has hours on a day they were not enrolled.
    spans = await hours_spans(db, {pupil for pupil, _, _, _ in rows})
    ends: dict[tuple[date, str], time] = {}

    for pupil, day, band, finish in rows:
        key = (day, band)

        if key in published and is_enrolled_on(day, spans.get(pupil, [])):
            ends[key] = max(ends.get(key, finish), finish)

    return ends


async def _names(
    db: AsyncSession,
    tax_codes: Iterable[str],
) -> dict[str, tuple[str, str]]:
    codes = set(tax_codes)

    if not codes:
        return {}

    rows = await db.execute(
        select(Person.tax_code, Person.first_name, Person.last_name).where(
            Person.tax_code.in_(codes),
        ),
    )

    return {code: (first, last) for code, first, last in rows.tuples()}


async def _corrections(
    db: AsyncSession,
    day: date,
    band: str,
) -> dict[str, StudentHoursCorrection]:
    rows = await db.scalars(
        select(StudentHoursCorrection).where(
            StudentHoursCorrection.date == day,
            StudentHoursCorrection.band == band,
        ),
    )

    return {row.student_tax_code: row for row in rows}


def _row(
    tax_code: str,
    name: tuple[str, str],
    planned_rows: Sequence[PupilStretch] | None,
    correction: StudentHoursCorrection | None,
    account: PupilAccount,
    day: date,
    band: str,
    confirmed: tuple[str, list[Span]] | None = None,
) -> PupilRow:
    planned: list[Span] | None = None

    if planned_rows:
        mode, planned = _planned_of(planned_rows)
    else:
        mode = correction.mode if correction is not None else PRESENCE

    absent = correction is not None and correction.absent

    if absent:
        work: list[Span] = []
    elif correction is not None and correction.work is not None:
        work = _load(correction.work)
    else:
        work = planned or []

    # A confirmed band shows the hours it was confirmed with: payments read those.
    if confirmed is not None:
        work = confirmed[1]
        mode = confirmed[0] if work else mode

    return PupilRow(
        tax_code=tax_code,
        first_name=name[0],
        last_name=name[1],
        mode=mode,
        absent=absent,
        added=correction is not None and correction.added,
        planned=planned,
        work=work,
        situation=band_situation(
            account,
            day,
            band,
            [(time_of(start), time_of(end)) for start, end in work],
            mode == ONLINE,
        ),
    )


def _status(
    confirmation: StudentConfirmedBand | None,
    planned: bool,
    rows: Sequence[PupilRow],
    last_end: int | None,
    day: date,
    now: datetime,
) -> BandStatus:
    if confirmation is not None and not confirmation.reopened:
        return BandStatus.CONFIRMED

    # Reopened and emptied, it still owes a confirmation; till then the old hours count.
    if confirmation is not None and not rows:
        return BandStatus.READY

    if not planned and not rows:
        return BandStatus.EMPTY

    if not rows:
        return BandStatus.WAITING

    if last_end is not None and not _arrived(day, last_end, now):
        return BandStatus.LIVE

    return BandStatus.READY


async def band_summary(
    db: AsyncSession,
    day: date,
    band: str,
    now: datetime,
) -> PupilBandSummary:
    calendar = await pupil_band_rows(db, day, band)
    corrections = await _corrections(db, day, band)

    # Nobody has hours on a day they were not enrolled.
    enrolled = await enrolled_on(db, [*calendar, *corrections], day)
    calendar = {key: rows for key, rows in calendar.items() if key in enrolled}
    corrections = {
        key: row for key, row in corrections.items() if key in enrolled
    }
    confirmation = await db.get(StudentConfirmedBand, (day, band))

    arrivals = {
        tax_code: max(minutes_of(end) for _, _, end in stretches)
        for tax_code, stretches in calendar.items()
    }
    added = [
        tax_code
        for tax_code, correction in corrections.items()
        if correction.added and tax_code not in calendar
    ]

    shown = [
        tax_code
        for tax_code, end in arrivals.items()
        if _arrived(day, end, now)
        or (confirmation is not None and not confirmation.reopened)
    ]

    is_confirmed = confirmation is not None and not confirmation.reopened
    stored = await _confirmed_spans(db, day, band) if is_confirmed else {}
    # Whoever was confirmed and no longer shows from the calendar still counts.
    kept = [tax_code for tax_code in stored if tax_code not in {*shown, *added}]
    names = await _names(db, [*calendar, *added, *kept])

    rows = [
        _row(
            tax_code,
            names.get(tax_code, ("", "")),
            calendar.get(tax_code),
            corrections.get(tax_code),
            await pupil_account(db, tax_code, now),
            day,
            band,
            stored.get(tax_code, (PRESENCE, [])) if is_confirmed else None,
        )
        for tax_code in [*shown, *added, *kept]
    ]
    rows.sort(key=lambda row: (row.first_name.casefold(), row.last_name.casefold()))

    # Hours written by hand count too: none is confirmed before it is over.
    ends = [
        *arrivals.values(),
        *(max(end for _, end in row.work) for row in rows if row.work),
    ]
    still = [end for end in ends if not _arrived(day, end, now)]
    last_end = max(ends, default=None)

    return PupilBandSummary(
        day=day,
        band=band,
        status=_status(confirmation, bool(calendar), rows, last_end, day, now),
        rows=rows,
        waiting=sorted(
            " ".join(names.get(tax_code, ("", ""))).strip()
            for tax_code in arrivals
            if tax_code not in shown
        ),
        waiting_tax_codes=sorted(
            tax_code for tax_code in arrivals if tax_code not in shown
        ),
        first_end=min(arrivals.values()) if arrivals else None,
        last_end=last_end,
        next_arrival=min(still) if still and day == now.date() else None,
        reopened=confirmation is not None and confirmation.reopened,
    )


# The hours a band was confirmed with, pupil by pupil, with their mode.
async def _confirmed_spans(
    db: AsyncSession,
    day: date,
    band: str,
) -> dict[str, tuple[str, list[Span]]]:
    rows = await db.execute(
        select(
            StudentConfirmedHours.student_tax_code,
            StudentConfirmedHours.mode,
            StudentConfirmedHours.start_time,
            StudentConfirmedHours.end_time,
        ).where(
            StudentConfirmedHours.date == day,
            StudentConfirmedHours.band == band,
        ),
    )
    spans: dict[str, tuple[str, list[Span]]] = {}

    for tax_code, mode, start, end in rows.tuples():
        spans.setdefault(tax_code, (mode, []))[1].append(
            (minutes_of(start), minutes_of(end)),
        )

    return {code: (mode, sorted(listed)) for code, (mode, listed) in spans.items()}


async def _assert_editable(db: AsyncSession, day: date, band: str) -> None:
    confirmation = await db.get(StudentConfirmedBand, (day, band))

    if confirmation is not None and not confirmation.reopened:
        raise _conflict(_CONFIRMED_ERROR.for_request())


def _check_span(span: Span, band: str) -> None:
    low, high = (minutes_of(bound) for bound in band_bounds(TimeBandEnum(band)))
    start, end = span

    if (
        start % STEP_MINUTES
        or end % STEP_MINUTES
        or end <= start
        or start < low
        or end > high
    ):
        raise _bad_request(_BAD_TIME_ERROR.for_request())


def _check_work(work: Sequence[Span], band: str) -> list[Span]:
    if not work:
        raise _bad_request(_NO_HOURS_ERROR.for_request())

    for span in work:
        _check_span(span, band)

    ordered = sorted(work)

    for before, after in zip(ordered, ordered[1:], strict=False):
        if after[0] < before[1]:
            raise _bad_request(_OVERLAP_ERROR.for_request())

    return ordered


async def update_row(
    db: AsyncSession,
    day: date,
    band: str,
    tax_code: str,
    now: datetime,
    *,
    work: Sequence[Span] | _Unset = UNSET,
    absent: bool | _Unset = UNSET,
) -> None:
    await _assert_editable(db, day, band)

    planned_rows = (await pupil_band_rows(db, day, band)).get(tax_code)
    correction = await db.get(StudentHoursCorrection, (day, band, tax_code))

    if planned_rows is not None:
        mode, planned = _planned_of(planned_rows)

        if not _arrived(day, max(end for _, end in planned), now):
            gender = await PersonRepository(db).gender(tax_code)

            raise _conflict(_NOT_ARRIVED_ERRORS[gender].for_request())

        if correction is None:
            correction = StudentHoursCorrection(
                date=day,
                band=band,
                student_tax_code=tax_code,
                mode=mode,
            )
            db.add(correction)

        correction.mode = mode

    if correction is None or (planned_rows is None and not correction.added):
        gender = await PersonRepository(db).gender(tax_code)

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOT_IN_BAND_ERRORS[gender].for_request(),
        )

    if not isinstance(absent, _Unset):
        correction.absent = absent

    if not isinstance(work, _Unset):
        correction.work = _dump(_check_work(work, band))

    await db.flush()


async def add_row(
    db: AsyncSession,
    day: date,
    band: str,
    tax_code: str,
    mode: str,
    work: Sequence[Span],
    now: datetime,
) -> None:
    await _assert_editable(db, day, band)
    assert_band_begun(day, band, now)

    if await db.get(Student, tax_code) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_STUDENT_NOT_FOUND_ERROR.for_request(),
        )

    if tax_code not in await enrolled_on(db, [tax_code], day):
        gender = await PersonRepository(db).gender(tax_code)

        raise _conflict(_NOT_ENROLLED_ERRORS[gender].for_request())

    if tax_code in await pupil_band_rows(db, day, band) or await db.get(
        StudentHoursCorrection,
        (day, band, tax_code),
    ):
        gender = await PersonRepository(db).gender(tax_code)

        raise _conflict(_ALREADY_IN_BAND_ERRORS[gender].for_request())

    db.add(
        StudentHoursCorrection(
            date=day,
            band=band,
            student_tax_code=tax_code,
            mode=mode,
            added=True,
            work=_dump(_check_work(work, band)),
        )
    )
    await db.flush()


# Back to the calendar, or out of the summary for a row added by hand.
async def drop_row(db: AsyncSession, day: date, band: str, tax_code: str) -> None:
    await _assert_editable(db, day, band)

    correction = await db.get(StudentHoursCorrection, (day, band, tax_code))

    if correction is not None:
        await db.delete(correction)
        await db.flush()


# Again on the same band, the new hours replace the old; a pupil left out has
# done nothing in it. What was settled of the band stays settled.
async def confirm_pupils(
    db: AsyncSession,
    day: date,
    band: str,
    rows: Sequence[PupilRow],
    *,
    by: str | None = None,
    at: datetime | None = None,
) -> None:
    await db.execute(
        delete(StudentConfirmedBand).where(
            StudentConfirmedBand.date == day,
            StudentConfirmedBand.band == band,
        ),
    )

    confirmed = StudentConfirmedBand(date=day, band=band, confirmed_by_tax_code=by)

    if at is not None:
        confirmed.confirmed_at = at

    db.add(confirmed)
    await db.flush()

    db.add_all(
        StudentConfirmedHours(
            student_tax_code=row.tax_code,
            date=day,
            band=band,
            mode=row.mode,
            start_time=time_of(start),
            end_time=time_of(end),
        )
        for row in rows
        if not row.absent
        for start, end in merge(row.work)
    )
    await db.flush()


async def confirm(
    db: AsyncSession,
    day: date,
    band: str,
    now: datetime,
    by: str | None,
) -> None:
    summary = await band_summary(db, day, band, now)

    if summary.status == BandStatus.CONFIRMED:
        raise _conflict(_ALREADY_CONFIRMED_ERROR.for_request())

    waiting = summary.status in (BandStatus.WAITING, BandStatus.LIVE)

    if waiting and summary.last_end is not None:
        raise _conflict(confirm_from_error(summary.last_end))

    if summary.status == BandStatus.EMPTY:
        raise _conflict(_NOTHING_TO_CONFIRM_ERROR.for_request())

    # Emptied after confirming: the old confirmation goes and its hours with it.
    if not summary.rows:
        await db.execute(
            delete(StudentConfirmedBand).where(
                StudentConfirmedBand.date == day,
                StudentConfirmedBand.band == band,
            ),
        )
        await db.flush()

        return

    await confirm_pupils(db, day, band, summary.rows, by=by, at=now)


async def reopen(db: AsyncSession, day: date, band: str) -> None:
    confirmation = await db.get(StudentConfirmedBand, (day, band))

    if confirmation is None or confirmation.reopened:
        raise _conflict(_NOT_CONFIRMED_ERROR.for_request())

    confirmation.reopened = True
    await db.flush()
