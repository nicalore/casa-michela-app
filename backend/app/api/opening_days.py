from __future__ import annotations

from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, BackgroundTasks, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.booking_window import today_in_rome
from app.models.opening_day import OpeningDay
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.schemas.opening_day import (
    OpeningDayCreate,
    OpeningDayReplace,
    OpeningDayResponse,
    OpeningDayRestoreRequest,
    OpeningDayRestoreResponse,
    OpeningDayUpdate,
    OpeningHoursChanged,
    OpeningModeEnum,
)
from app.services import push
from app.services.opening_day_service import OpeningDayService
from app.services.opening_hours_changed import announce_hours_change

router = APIRouter(
    prefix="/opening-days",
    tags=["opening-days"],
    dependencies=[
        Depends(
            require_role(
                "ADMIN",
                "TEACHER",
                "STUDENT",
                "PARENT",
                "PSYCHOLOGIST",
                "COURSE_PARTICIPANT",
            )
        )
    ],
)

_ADMIN_ONLY = [Depends(require_role("ADMIN"))]


def _to_response(opening_day: OpeningDay) -> OpeningDayResponse:
    return OpeningDayResponse.model_validate(opening_day)


def _to_responses(opening_days: Sequence[OpeningDay]) -> list[OpeningDayResponse]:
    return [_to_response(opening_day) for opening_day in opening_days]


def _service(db: DbSession) -> OpeningDayService:
    return OpeningDayService(OpeningDayRepository(db), WeeklyTemplateRepository(db))


@router.get("/", response_model=list[OpeningDayResponse])
async def list_opening_days(
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
    mode: OpeningModeEnum | None = None,
) -> list[OpeningDayResponse]:
    opening_days = await _service(db).list_for(
        date_from=date_from,
        date_to=date_to,
        mode=mode.value if mode is not None else None,
    )

    return _to_responses(opening_days)


@router.post("/", response_model=OpeningDayResponse, dependencies=_ADMIN_ONLY)
async def create_opening_day(
    payload: OpeningDayCreate,
    db: DbSession,
) -> OpeningDayResponse:
    opening_day = await _service(db).create(payload)

    return _to_response(opening_day)


# Declared before the {opening_day_id} routes so the segment is not intercepted.
@router.put(
    "/day",
    response_model=list[OpeningDayResponse],
    dependencies=_ADMIN_ONLY,
)
async def replace_day(
    payload: OpeningDayReplace,
    db: DbSession,
) -> list[OpeningDayResponse]:
    return _to_responses(await _service(db).replace_day(payload))


@router.post(
    "/restore-standard",
    response_model=OpeningDayRestoreResponse,
    dependencies=_ADMIN_ONLY,
)
async def restore_standard_hours(
    payload: OpeningDayRestoreRequest,
    db: DbSession,
) -> OpeningDayRestoreResponse:
    dates_restored, rows_created = await _service(db).restore_standard(
        date_from=payload.date_from,
        date_to=payload.date_to,
        mode=payload.mode.value,
        confirmed=payload.confirm,
    )

    return OpeningDayRestoreResponse(
        dates_restored=dates_restored,
        rows_created=rows_created,
    )


# Called once a variation is saved, so a range written day by day makes one notice.
@router.post(
    "/announce",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=_ADMIN_ONLY,
)
async def announce_hours(
    payload: OpeningHoursChanged,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    batch = await announce_hours_change(
        db,
        payload.date_from,
        payload.date_to,
        author=identity.tax_code,
        today=today_in_rome(),
    )
    await db.commit()
    background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{opening_day_id}", response_model=OpeningDayResponse)
async def get_opening_day(
    opening_day_id: int,
    db: DbSession,
) -> OpeningDayResponse:
    opening_day = await _service(db).get_or_404(opening_day_id)

    return _to_response(opening_day)


@router.put(
    "/{opening_day_id}",
    response_model=OpeningDayResponse,
    dependencies=_ADMIN_ONLY,
)
async def update_opening_day(
    opening_day_id: int,
    payload: OpeningDayUpdate,
    db: DbSession,
) -> OpeningDayResponse:
    opening_day = await _service(db).update(opening_day_id, payload)

    return _to_response(opening_day)


@router.delete("/{opening_day_id}", dependencies=_ADMIN_ONLY)
async def delete_opening_day(
    opening_day_id: int,
    db: DbSession,
    confirm: bool = False,
) -> dict[str, str]:
    await _service(db).delete(opening_day_id, confirmed=confirm)

    return {"detail": "Apertura eliminata"}
