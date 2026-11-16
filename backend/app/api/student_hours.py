from datetime import date, time
from typing import Annotated, Literal

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.student_hours import (
    StudentHoursBandResponse,
    StudentHoursRowCreate,
    StudentHoursRowResponse,
    StudentHoursRowUpdate,
    StudentSituationResponse,
)
from app.schemas.teacher_hours import HoursSpan
from app.services import student_hours
from app.services.accounting_lock import lock_band
from app.services.student_hours import UNSET, PupilBandSummary, PupilRow
from app.services.worked_hours import Span, minutes_of, time_of

router = APIRouter(prefix="/accounting/student-hours", tags=["accounting"])

Band = Literal["MORNING", "AFTERNOON", "EVENING"]

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


def _span(span: Span) -> HoursSpan:
    return HoursSpan(start_time=time_of(span[0]), end_time=time_of(span[1]))


def _minutes(span: HoursSpan) -> Span:
    return (minutes_of(span.start_time), minutes_of(span.end_time))


def _time(minutes: int | None) -> time | None:
    return None if minutes is None else time_of(minutes)


def _row(row: PupilRow) -> StudentHoursRowResponse:
    situation = row.situation

    return StudentHoursRowResponse(
        tax_code=row.tax_code,
        first_name=row.first_name,
        last_name=row.last_name,
        mode=row.mode,
        absent=row.absent,
        added=row.added,
        planned=None if row.planned is None else [_span(span) for span in row.planned],
        work=[_span(span) for span in row.work],
        minutes=row.minutes,
        situation=StudentSituationResponse(
            kind=situation.kind,
            tariff_kind=(
                None if situation.tariff_kind is None else situation.tariff_kind.value
            ),
            tariff_cents=situation.tariff_cents,
            package_hours=situation.package_hours,
            minutes=situation.minutes,
            renewed=situation.renewed,
            cost_cents=situation.cost_cents,
        ),
    )


def _band(summary: PupilBandSummary) -> StudentHoursBandResponse:
    return StudentHoursBandResponse(
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


async def _summary(db: DbSession, day: date, band: str) -> StudentHoursBandResponse:
    return _band(await student_hours.band_summary(db, day, band, now_in_rome()))


@router.get("/{day}/{band}", response_model=StudentHoursBandResponse)
async def get_band(
    day: date,
    band: Band,
    db: DbSession,
    _: Admin,
) -> StudentHoursBandResponse:
    return await _summary(db, day, band)


@router.put("/{day}/{band}/{tax_code}", response_model=StudentHoursBandResponse)
async def update_row(
    day: date,
    band: Band,
    tax_code: str,
    payload: StudentHoursRowUpdate,
    db: DbSession,
    _: Admin,
) -> StudentHoursBandResponse:
    await lock_band(db, "pupils", day, band)
    await student_hours.update_row(
        db,
        day,
        band,
        tax_code.upper(),
        now_in_rome(),
        work=(
            [_minutes(span) for span in payload.work]
            if payload.work is not None
            else UNSET
        ),
        absent=payload.absent if payload.absent is not None else UNSET,
    )
    await db.commit()

    return await _summary(db, day, band)


@router.post("/{day}/{band}", response_model=StudentHoursBandResponse)
async def add_row(
    day: date,
    band: Band,
    payload: StudentHoursRowCreate,
    db: DbSession,
    _: Admin,
) -> StudentHoursBandResponse:
    await lock_band(db, "pupils", day, band)
    await student_hours.add_row(
        db,
        day,
        band,
        payload.tax_code.upper(),
        payload.mode,
        [_minutes(span) for span in payload.work],
        now_in_rome(),
    )
    await db.commit()

    return await _summary(db, day, band)


# Back to the calendar; a row added by hand leaves the summary.
@router.delete("/{day}/{band}/{tax_code}", response_model=StudentHoursBandResponse)
async def drop_row(
    day: date,
    band: Band,
    tax_code: str,
    db: DbSession,
    _: Admin,
) -> StudentHoursBandResponse:
    await lock_band(db, "pupils", day, band)
    await student_hours.drop_row(db, day, band, tax_code.upper())
    await db.commit()

    return await _summary(db, day, band)


@router.post("/{day}/{band}/confirm", response_model=StudentHoursBandResponse)
async def confirm_band(
    day: date,
    band: Band,
    db: DbSession,
    identity: Admin,
) -> StudentHoursBandResponse:
    await lock_band(db, "pupils", day, band)
    await student_hours.confirm(db, day, band, now_in_rome(), identity.tax_code)
    await db.commit()

    return await _summary(db, day, band)


# «MODIFICA ORE»: open again, the confirmed hours still count until the next one.
@router.post("/{day}/{band}/reopen", response_model=StudentHoursBandResponse)
async def reopen_band(
    day: date,
    band: Band,
    db: DbSession,
    _: Admin,
) -> StudentHoursBandResponse:
    await lock_band(db, "pupils", day, band)
    await student_hours.reopen(db, day, band)
    await db.commit()

    return await _summary(db, day, band)
