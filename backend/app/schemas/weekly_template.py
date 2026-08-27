from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.opening_day import OpeningModeEnum
from app.schemas.validators import TimeRangeMixin


class WeeklyTemplateBase(TimeRangeMixin):
    weekday: int = Field(..., ge=1, le=7)
    mode: OpeningModeEnum


class _EffectiveFromMixin(BaseModel):
    # From when the change reaches already-generated opening_days rows;
    # None means no propagation.
    effective_from: date | None = None

    # Caller confirms they know what the change costs published calendars.
    confirm: bool = False


class WeeklyTemplateCreate(WeeklyTemplateBase, _EffectiveFromMixin):
    pass


# weekday and mode are immutable through the API: they keep the propagation
# towards opening_days well defined (see WeeklyTemplateService.update).
class WeeklyTemplateUpdate(TimeRangeMixin, _EffectiveFromMixin):
    expected_updated_at: datetime | None = None


class WeeklyTemplateResponse(WeeklyTemplateBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    effective_from: date
    updated_at: datetime
