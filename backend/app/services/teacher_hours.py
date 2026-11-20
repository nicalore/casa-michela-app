from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from enum import StrEnum
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.i18n import tr
from app.core.time_band import TimeBandEnum, band_bounds
from app.models.confirmed_hours import ConfirmedBand, ConfirmedHours, HoursCorrection
from app.models.person import GenderEnum, Person
from app.models.staff import CollaborationTypeEnum
from app.models.teacher import Teacher
from app.repositories.person_repository import PersonRepository
from app.services.bilingual import Bilingual
from app.services.compensation import (
    TermsTimeline,
    allot_volunteering,
    amount,
    load_terms,
    monday_of,
    net_of,
    worked_bands,
)
from app.services.confirmed_hours import ConfirmedRow, confirm_band
from app.services.enrollment_spans import enrolled_on
from app.services.worked_hours import (
    ONLINE,
    PRESENCE,
    BandWork,
    CalendarRow,
    Span,
    band_key,
    band_rows,
    minutes_of,
    span_minutes,
    time_of,
    work_of,
)

STEP_MINUTES: Final[int] = 15

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
        "Il docente non è nel riepilogo di questa fascia.",
        "The teacher is not in this time slot's summary.",
    ),
    GenderEnum.F: Bilingual(
        "La docente non è nel riepilogo di questa fascia.",
        "The teacher is not in this time slot's summary.",
    ),
}
_NOT_ARRIVED_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Le ore del docente si correggono quando finisce la sua ultima lezione.",
        "The teacher's hours can be corrected once their last lesson ends.",
    ),
    GenderEnum.F: Bilingual(
        "Le ore della docente si correggono quando finisce la sua ultima lezione.",
        "The teacher's hours can be corrected once their last lesson ends.",
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
        "Il docente è già nel riepilogo di questa fascia.",
        "The teacher is already in this time slot's summary.",
    ),
    GenderEnum.F: Bilingual(
        "La docente è già nel riepilogo di questa fascia.",
        "The teacher is already in this time slot's summary.",
    ),
}
_TEACHER_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Docente non trovato.",
    "Teacher not found.",
)
_NO_WORK_ERROR: Final[Bilingual] = Bilingual(
    "Indica almeno un orario di lavoro.",
    "Enter at least one working time.",
)
_BAD_TIME_ERROR: Final[Bilingual] = Bilingual(
    "Gli orari vanno a quarti d'ora, dentro la fascia.",
    "Times go by quarter hours, within the time slot.",
)
_OVERLAP_ERROR: Final[Bilingual] = Bilingual(
    "Gli orari non possono sovrapporsi.",
    "Times cannot overlap.",
)
_NO_VOLUNTEERING_ERROR: Final[Bilingual] = Bilingual(
    "Il volontariato si segna solo a chi è retribuito e lavora in presenza.",
    "Volunteering is marked only for paid staff working in person.",
)
_NOT_BEGUN_ERROR: Final[Bilingual] = Bilingual(
    "Questa fascia non è ancora cominciata.",
    "This time slot has not started yet.",
)
_VOLUNTEER_OUTSIDE_ERROR: Final[Bilingual] = Bilingual(
    "Il volontariato deve stare dentro l'orario di lavoro.",
    "Volunteering must fall within the working hours.",
)


class BandStatus(StrEnum):
    # No lesson planned, nobody added.
    EMPTY = "EMPTY"
    # Lessons planned, none over yet.
    WAITING = "WAITING"
    # Some rows in, the last lesson still to end.
    LIVE = "LIVE"
    # Every lesson over: it can be confirmed.
    READY = "READY"
    CONFIRMED = "CONFIRMED"


# Left out of a partial update: not the same as None, which clears.
class _Unset:
    pass


UNSET: Final[_Unset] = _Unset()


@dataclass(frozen=True)
class HoursRow:
    tax_code: str
    first_name: str
    last_name: str
    mode: str
    collaboration_type: CollaborationTypeEnum
    absent: bool
    added: bool
    planned: list[Span] | None
    work: list[Span]
    volunteer: Span | None
    volunteer_proposed: Span | None
    volunteer_set: bool
    gross: Decimal | None
    net: Decimal | None
    # What the rule's hour takes past its first stretch, when the work has a gap.
    volunteer_rest: int = 0

    @property
    def worked_minutes(self) -> int:
        return span_minutes(self.work)

    @property
    def volunteer_minutes(self) -> int:
        shown = 0 if self.volunteer is None else span_minutes([self.volunteer])

        return shown + self.volunteer_rest


@dataclass(frozen=True)
class BandSummary:
    day: date
    band: str
    status: BandStatus
    rows: list[HoursRow]
    # Teachers whose last lesson is still to end, named.
    waiting: list[str]
    # The same, for whoever adds a teacher: they cannot be added twice.
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


def confirm_from_error(last_end: int) -> str:
    at = time_of(last_end).strftime("%H:%M")

    return tr(
        f"Si potrà confermare dalle {at}, quando finirà l'ultima lezione.",
        f"It can be confirmed from {at}, when the last lesson ends.",
    )


def _minute_of(moment: datetime) -> int:
    return moment.hour * 60 + moment.minute


def _arrived(day: date, end: int, now: datetime) -> bool:
    return day < now.date() or (day == now.date() and end <= _minute_of(now))


def _planned_of(rows: Sequence[CalendarRow]) -> tuple[str, list[Span]]:
    presence, spans = work_of((mode, start, end) for _, _, _, mode, start, end in rows)

    return (PRESENCE if presence else ONLINE), spans


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
) -> dict[str, HoursCorrection]:
    rows = await db.scalars(
        select(HoursCorrection).where(
            HoursCorrection.date == day,
            HoursCorrection.band == band,
        ),
    )

    return {row.teacher_tax_code: row for row in rows}


def _may_volunteer(timeline: TermsTimeline, day: date, mode: str) -> bool:
    return timeline.counts(day) and mode == PRESENCE


# What the month's rule leaves to this band, after the bands before it this week:
# one piece, or one per stretch when the hour runs on past a gap.
async def volunteer_pieces(
    db: AsyncSession,
    tax_code: str,
    day: date,
    band: str,
    work: Sequence[Span],
    timeline: TermsTimeline | None = None,
) -> list[Span]:
    timeline = timeline or await load_terms(db, tax_code)

    if not work or not timeline.counts(day):
        return []

    here = band_key(day, band)
    earlier = [
        before
        for before in await worked_bands(
            db,
            tax_code,
            monday_of(day),
            day + timedelta(days=1),
            lambda _day, _end: True,
        )
        if before.key < here
    ]

    allotted = allot_volunteering(
        [*earlier, BandWork(day=day, band=band, presence=True, spans=list(work))],
        timeline.counts,
        timeline.rule,
    ).get((day, band))

    return allotted or []


async def volunteer_proposal(
    db: AsyncSession,
    tax_code: str,
    day: date,
    band: str,
    work: Sequence[Span],
    timeline: TermsTimeline | None = None,
) -> Span | None:
    pieces = await volunteer_pieces(db, tax_code, day, band, work, timeline)

    return pieces[0] if pieces else None


async def _row(
    db: AsyncSession,
    tax_code: str,
    name: tuple[str, str],
    planned_rows: Sequence[CalendarRow] | None,
    correction: HoursCorrection | None,
    day: date,
    band: str,
    confirmed: tuple[str, list[Span]] | None = None,
) -> HoursRow:
    timeline = await load_terms(db, tax_code)
    terms = timeline.of_month(day.replace(day=1))

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

    # A confirmed band shows the hours it was confirmed with: pay reads those.
    if confirmed is not None:
        work = confirmed[1]
        mode = confirmed[0] if work else mode

    volunteer_set = correction is not None and correction.volunteer_set
    proposed = None
    volunteer = None
    rest = 0

    if not absent and work and _may_volunteer(timeline, day, mode):
        pieces = await volunteer_pieces(db, tax_code, day, band, work, timeline)
        proposed = pieces[0] if pieces else None

        if volunteer_set and correction is not None:
            start, end = correction.volunteer_start, correction.volunteer_end
            volunteer = (
                None
                if start is None or end is None
                else (minutes_of(start), minutes_of(end))
            )
        else:
            volunteer = proposed
            rest = span_minutes(pieces[1:])

    given = (0 if volunteer is None else span_minutes([volunteer])) + rest
    paid = span_minutes(work) - given
    rate = terms.rate
    month = day.replace(day=1)
    waiting = timeline.pending_in(month)
    priced = rate is not None and timeline.counted(day) and not waiting
    gross = amount(paid, rate) if priced and rate is not None else None

    return HoursRow(
        tax_code=tax_code,
        first_name=name[0],
        last_name=name[1],
        mode=mode,
        collaboration_type=terms.collaboration_type,
        absent=absent,
        added=correction is not None and correction.added,
        planned=planned,
        work=work,
        volunteer=volunteer,
        volunteer_proposed=proposed,
        volunteer_set=volunteer_set,
        gross=gross,
        net=None if gross is None else net_of(gross),
        volunteer_rest=rest,
    )


# Nobody is written by hand into a band still to come.
def assert_band_begun(day: date, band: str, now: datetime) -> None:
    low, _ = band_bounds(TimeBandEnum(band))

    if not _arrived(day, minutes_of(low), now):
        raise _conflict(_NOT_BEGUN_ERROR.for_request())


def _status(
    confirmation: ConfirmedBand | None,
    planned: bool,
    rows: Sequence[HoursRow],
    last_end: int | None,
    day: date,
    now: datetime,
) -> BandStatus:
    if confirmation is not None and not confirmation.reopened:
        return BandStatus.CONFIRMED

    # Reopened and emptied, it still owes a confirmation: until then pay keeps the old hours.
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
) -> BandSummary:
    calendar = await band_rows(db, day, band)
    corrections = await _corrections(db, day, band)

    # Nobody has hours on a day they were not enrolled.
    enrolled = await enrolled_on(db, [*calendar, *corrections], day)
    calendar = {key: rows for key, rows in calendar.items() if key in enrolled}
    corrections = {
        key: row for key, row in corrections.items() if key in enrolled
    }
    confirmation = await db.get(ConfirmedBand, (day, band))

    arrivals = {
        tax_code: max(minutes_of(row[5]) for row in rows)
        for tax_code, rows in calendar.items()
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
    # Whoever was confirmed and no longer shows from the calendar is still paid.
    kept = [tax_code for tax_code in stored if tax_code not in {*shown, *added}]
    names = await _names(db, [*calendar, *added, *kept])

    rows = [
        await _row(
            db,
            tax_code,
            names.get(tax_code, ("", "")),
            calendar.get(tax_code),
            corrections.get(tax_code),
            day,
            band,
            stored.get(tax_code, (PRESENCE, [])) if is_confirmed else None,
        )
        for tax_code in [*shown, *added, *kept]
    ]

    # Hours written by hand count too: none is confirmed before it is over.
    ends = [
        *arrivals.values(),
        *(max(end for _, end in row.work) for row in rows if row.work),
    ]
    still = [end for end in ends if not _arrived(day, end, now)]
    last_end = max(ends, default=None)

    return BandSummary(
        day=day,
        band=band,
        status=_status(confirmation, bool(calendar), rows, last_end, day, now),
        rows=rows,
        waiting=sorted(
            " ".join(names.get(tax_code, ("", ""))).strip()
            for tax_code, end in arrivals.items()
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


# The hours a band was confirmed with, teacher by teacher, with their mode.
async def _confirmed_spans(
    db: AsyncSession,
    day: date,
    band: str,
) -> dict[str, tuple[str, list[Span]]]:
    rows = await db.execute(
        select(
            ConfirmedHours.teacher_tax_code,
            ConfirmedHours.mode,
            ConfirmedHours.start_time,
            ConfirmedHours.end_time,
        ).where(ConfirmedHours.date == day, ConfirmedHours.band == band),
    )
    spans: dict[str, tuple[str, list[Span]]] = {}

    for tax_code, mode, start, end in rows.tuples():
        spans.setdefault(tax_code, (mode, []))[1].append(
            (minutes_of(start), minutes_of(end)),
        )

    return {code: (mode, sorted(listed)) for code, (mode, listed) in spans.items()}


async def _assert_editable(db: AsyncSession, day: date, band: str) -> None:
    confirmation = await db.get(ConfirmedBand, (day, band))

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


# In person the calendar gives one stretch, gaps paid; stretches written by hand
# leave the time between them unpaid, as online.
def _check_work(work: Sequence[Span], band: str) -> list[Span]:
    if not work:
        raise _bad_request(_NO_WORK_ERROR.for_request())

    for span in work:
        _check_span(span, band)

    ordered = sorted(work)

    for before, after in zip(ordered, ordered[1:], strict=False):
        if after[0] < before[1]:
            raise _bad_request(_OVERLAP_ERROR.for_request())

    return ordered


def _check_volunteer(volunteer: Span, work: Sequence[Span], band: str) -> None:
    _check_span(volunteer, band)

    if not any(start <= volunteer[0] and volunteer[1] <= end for start, end in work):
        raise _bad_request(_VOLUNTEER_OUTSIDE_ERROR.for_request())


def _set_volunteer(correction: HoursCorrection, volunteer: Span | None) -> None:
    correction.volunteer_set = True
    correction.volunteer_start = None if volunteer is None else time_of(volunteer[0])
    correction.volunteer_end = None if volunteer is None else time_of(volunteer[1])


# New hours keep what of the volunteering still falls inside them.
def _clamp_volunteer(correction: HoursCorrection, work: Sequence[Span]) -> None:
    start, end = correction.volunteer_start, correction.volunteer_end

    if not correction.volunteer_set or start is None or end is None:
        return

    for low, high in work:
        clipped = (max(minutes_of(start), low), min(minutes_of(end), high))

        if clipped[1] > clipped[0]:
            _set_volunteer(correction, clipped)

            return

    _set_volunteer(correction, None)


async def update_row(
    db: AsyncSession,
    day: date,
    band: str,
    tax_code: str,
    now: datetime,
    *,
    work: Sequence[Span] | _Unset = UNSET,
    volunteer: Span | None | _Unset = UNSET,
    absent: bool | _Unset = UNSET,
) -> None:
    await _assert_editable(db, day, band)

    planned_rows = (await band_rows(db, day, band)).get(tax_code)
    correction = await db.get(HoursCorrection, (day, band, tax_code))

    planned: list[Span] = []

    if planned_rows is not None:
        mode, planned = _planned_of(planned_rows)

        if not _arrived(day, max(end for _, end in planned), now):
            gender = await PersonRepository(db).gender(tax_code)

            raise _conflict(_NOT_ARRIVED_ERRORS[gender].for_request())

        if correction is None:
            correction = HoursCorrection(
                date=day,
                band=band,
                teacher_tax_code=tax_code,
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
        ordered = _check_work(work, band)
        correction.work = _dump(ordered)
        _clamp_volunteer(correction, ordered)

    if not isinstance(volunteer, _Unset):
        timeline = await load_terms(db, tax_code)

        if volunteer is not None:
            if not _may_volunteer(timeline, day, correction.mode):
                raise _bad_request(_NO_VOLUNTEERING_ERROR.for_request())

            current = planned if correction.work is None else _load(correction.work)
            _check_volunteer(volunteer, current, band)

        _set_volunteer(correction, volunteer)

    await db.flush()


async def add_row(
    db: AsyncSession,
    day: date,
    band: str,
    tax_code: str,
    mode: str,
    work: Sequence[Span],
    now: datetime,
    *,
    volunteer: Span | None | _Unset = UNSET,
) -> None:
    await _assert_editable(db, day, band)
    assert_band_begun(day, band, now)

    if await db.get(Teacher, tax_code) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_TEACHER_NOT_FOUND_ERROR.for_request(),
        )

    if tax_code not in await enrolled_on(db, [tax_code], day):
        gender = await PersonRepository(db).gender(tax_code)

        raise _conflict(_NOT_ENROLLED_ERRORS[gender].for_request())

    if tax_code in await band_rows(db, day, band) or await db.get(
        HoursCorrection,
        (day, band, tax_code),
    ):
        gender = await PersonRepository(db).gender(tax_code)

        raise _conflict(_ALREADY_IN_BAND_ERRORS[gender].for_request())

    ordered = _check_work(work, band)
    correction = HoursCorrection(
        date=day,
        band=band,
        teacher_tax_code=tax_code,
        mode=mode,
        added=True,
        work=_dump(ordered),
    )

    if not isinstance(volunteer, _Unset):
        if volunteer is not None:
            if not _may_volunteer(await load_terms(db, tax_code), day, mode):
                raise _bad_request(_NO_VOLUNTEERING_ERROR.for_request())

            _check_volunteer(volunteer, ordered, band)

        _set_volunteer(correction, volunteer)

    db.add(correction)
    await db.flush()


# Back to the calendar, or out of the summary for a row added by hand.
async def drop_row(db: AsyncSession, day: date, band: str, tax_code: str) -> None:
    await _assert_editable(db, day, band)

    correction = await db.get(HoursCorrection, (day, band, tax_code))

    if correction is not None:
        await db.delete(correction)
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

    # Emptied after confirming: nothing left to confirm, so the old confirmation goes
    # and the band is empty again, its hours out of pay.
    if not summary.rows:
        await db.execute(
            delete(ConfirmedBand).where(
                ConfirmedBand.date == day,
                ConfirmedBand.band == band,
            ),
        )
        await db.flush()

        return

    await confirm_band(
        db,
        day,
        band,
        {
            row.tax_code: ConfirmedRow(
                spans=row.work,
                mode=row.mode,
                volunteer=row.volunteer,
                volunteer_set=row.volunteer_set,
            )
            for row in summary.rows
            if not row.absent and row.work
        },
        by=by,
        at=now,
    )


async def reopen(db: AsyncSession, day: date, band: str) -> None:
    confirmation = await db.get(ConfirmedBand, (day, band))

    if confirmation is None or confirmation.reopened:
        raise _conflict(_NOT_CONFIRMED_ERROR.for_request())

    confirmation.reopened = True
    await db.flush()
