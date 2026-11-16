from datetime import date, time
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.teacher_hours import (
    HoursSpan,
    TeacherHoursBandResponse,
    TeacherHoursRowCreate,
    TeacherHoursRowResponse,
    TeacherHoursRowUpdate,
    VolunteerProposalResponse,
)
from app.services import teacher_hours
from app.services.accounting_lock import lock_band
from app.services.teacher_hours import UNSET, BandSummary, HoursRow
from app.services.worked_hours import Span, minutes_of, time_of

router = APIRouter(prefix="/accounting/teacher-hours", tags=["accounting"])

Band = Literal["MORNING", "AFTERNOON", "EVENING"]

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


def _span(span: Span) -> HoursSpan:
    return HoursSpan(start_time=time_of(span[0]), end_time=time_of(span[1]))


def _minutes(span: HoursSpan) -> Span:
    return (minutes_of(span.start_time), minutes_of(span.end_time))


def _time(minutes: int | None) -> time | None:
    return None if minutes is None else time_of(minutes)


def _row(row: HoursRow) -> TeacherHoursRowResponse:
    return TeacherHoursRowResponse(
        tax_code=row.tax_code,
        first_name=row.first_name,
        last_name=row.last_name,
        mode=row.mode,
        collaboration_type=row.collaboration_type.value,
        absent=row.absent,
        added=row.added,
        planned=None if row.planned is None else [_span(span) for span in row.planned],
        work=[_span(span) for span in row.work],
        volunteer=None if row.volunteer is None else _span(row.volunteer),
        volunteer_proposed=(
            None if row.volunteer_proposed is None else _span(row.volunteer_proposed)
        ),
        volunteer_set=row.volunteer_set,
        worked_minutes=row.worked_minutes,
        volunteer_minutes=row.volunteer_minutes,
        gross=row.gross,
        net=row.net,
    )


def _band(summary: BandSummary) -> TeacherHoursBandResponse:
    return TeacherHoursBandResponse(
        date=summary.day,
        band=summary.band,
        status=summary.status.value,
        rows=[_row(row) for row in summary.rows],
        waiting=summary.waiting,
        waiting_tax_codes=summary.waiting_tax_codes,
        first_end=_time(summary.first_end),
        last_end=_time(summary.last_end),
        next_arrival=_time(summary.next_arrival),
        reopened=summary.reopened,
    )


async def _summary(db: DbSession, day: date, band: str) -> TeacherHoursBandResponse:
    return _band(await teacher_hours.band_summary(db, day, band, now_in_rome()))


@router.get("/{day}/{band}", response_model=TeacherHoursBandResponse)
async def get_band(
    day: date,
    band: Band,
    db: DbSession,
    _: Admin,
) -> TeacherHoursBandResponse:
    return await _summary(db, day, band)


@router.put("/{day}/{band}/{tax_code}", response_model=TeacherHoursBandResponse)
async def update_row(
    day: date,
    band: Band,
    tax_code: str,
    payload: TeacherHoursRowUpdate,
    db: DbSession,
    _: Admin,
) -> TeacherHoursBandResponse:
    sent = payload.model_fields_set

    await lock_band(db, "teachers", day, band)
    await teacher_hours.update_row(
        db,
        day,
        band,
        tax_code.upper(),
        now_in_rome(),
        work=(
            [_minutes(span) for span in payload.work]
            if "work" in sent and payload.work is not None
            else UNSET
        ),
        volunteer=(
            (None if payload.volunteer is None else _minutes(payload.volunteer))
            if "volunteer" in sent
            else UNSET
        ),
        absent=payload.absent if payload.absent is not None else UNSET,
    )
    await db.commit()

    return await _summary(db, day, band)


@router.post("/{day}/{band}", response_model=TeacherHoursBandResponse)
async def add_row(
    day: date,
    band: Band,
    payload: TeacherHoursRowCreate,
    db: DbSession,
    _: Admin,
) -> TeacherHoursBandResponse:
    await lock_band(db, "teachers", day, band)
    await teacher_hours.add_row(
        db,
        day,
        band,
        payload.tax_code.upper(),
        payload.mode,
        [_minutes(span) for span in payload.work],
        now_in_rome(),
        volunteer=(
            (None if payload.volunteer is None else _minutes(payload.volunteer))
            if "volunteer" in payload.model_fields_set
            else UNSET
        ),
    )
    await db.commit()

    return await _summary(db, day, band)


# Back to the calendar; a row added by hand leaves the summary.
@router.delete("/{day}/{band}/{tax_code}", response_model=TeacherHoursBandResponse)
async def drop_row(
    day: date,
    band: Band,
    tax_code: str,
    db: DbSession,
    _: Admin,
) -> TeacherHoursBandResponse:
    await lock_band(db, "teachers", day, band)
    await teacher_hours.drop_row(db, day, band, tax_code.upper())
    await db.commit()

    return await _summary(db, day, band)


@router.post("/{day}/{band}/confirm", response_model=TeacherHoursBandResponse)
async def confirm_band(
    day: date,
    band: Band,
    db: DbSession,
    identity: Admin,
) -> TeacherHoursBandResponse:
    await lock_band(db, "teachers", day, band)
    await teacher_hours.confirm(db, day, band, now_in_rome(), identity.tax_code)
    await db.commit()

    return await _summary(db, day, band)


# «MODIFICA ORE»: open again, the confirmed hours still pay until the next one.
@router.post("/{day}/{band}/reopen", response_model=TeacherHoursBandResponse)
async def reopen_band(
    day: date,
    band: Band,
    db: DbSession,
    _: Admin,
) -> TeacherHoursBandResponse:
    await lock_band(db, "teachers", day, band)
    await teacher_hours.reopen(db, day, band)
    await db.commit()

    return await _summary(db, day, band)


# For the dialog that adds a teacher: what the weekly hour would give.
@router.get("/{day}/{band}/volunteering", response_model=VolunteerProposalResponse)
async def get_volunteer_proposal(
    day: date,
    band: Band,
    db: DbSession,
    _: Admin,
    tax_code: Annotated[str, Query(min_length=16, max_length=16)],
    start_time: Annotated[time, Query()],
    end_time: Annotated[time, Query()],
) -> VolunteerProposalResponse:
    proposal = await teacher_hours.volunteer_proposal(
        db,
        tax_code.upper(),
        day,
        band,
        [(minutes_of(start_time), minutes_of(end_time))],
    )

    return VolunteerProposalResponse(
        volunteer=None if proposal is None else _span(proposal),
    )
