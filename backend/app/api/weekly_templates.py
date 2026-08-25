from __future__ import annotations

from collections.abc import Sequence
from datetime import date

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import require_role
from app.models.weekly_template import WeeklyTemplate
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.schemas.weekly_template import (
    WeeklyTemplateCreate,
    WeeklyTemplateResponse,
    WeeklyTemplateUpdate,
)
from app.services.weekly_template_service import WeeklyTemplateService

router = APIRouter(
    prefix="/weekly-templates",
    tags=["weekly-templates"],
    dependencies=[Depends(require_role("ADMIN"))],
)


def _to_response(template: WeeklyTemplate) -> WeeklyTemplateResponse:
    return WeeklyTemplateResponse.model_validate(template)


def _to_responses(
    templates: Sequence[WeeklyTemplate],
) -> list[WeeklyTemplateResponse]:
    return [_to_response(template) for template in templates]


def _service(db: DbSession) -> WeeklyTemplateService:
    return WeeklyTemplateService(
        WeeklyTemplateRepository(db),
        OpeningDayRepository(db),
    )


@router.get("/", response_model=list[WeeklyTemplateResponse])
async def list_weekly_templates(db: DbSession) -> list[WeeklyTemplateResponse]:
    templates = await _service(db).list_all()

    return _to_responses(templates)


@router.post("/", response_model=WeeklyTemplateResponse)
async def create_weekly_template(
    payload: WeeklyTemplateCreate,
    db: DbSession,
) -> WeeklyTemplateResponse:
    template = await _service(db).create(payload)

    return _to_response(template)


@router.get("/{template_id}", response_model=WeeklyTemplateResponse)
async def get_weekly_template(
    template_id: int,
    db: DbSession,
) -> WeeklyTemplateResponse:
    template = await _service(db).get_or_404(template_id)

    return _to_response(template)


@router.put("/{template_id}", response_model=WeeklyTemplateResponse)
async def update_weekly_template(
    template_id: int,
    payload: WeeklyTemplateUpdate,
    db: DbSession,
) -> WeeklyTemplateResponse:
    template = await _service(db).update(template_id, payload)

    return _to_response(template)


@router.delete("/{template_id}")
async def delete_weekly_template(
    template_id: int,
    db: DbSession,
    effective_from: date | None = None,
    confirm: bool = False,
) -> dict[str, str]:
    # A query param rather than a body: DELETE with a body is not uniformly
    # supported across HTTP clients.
    await _service(db).delete(template_id, effective_from, confirmed=confirm)

    return {"detail": "Riga di template eliminata"}
