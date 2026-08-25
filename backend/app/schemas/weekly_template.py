from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.opening_day import OpeningModeEnum
from app.schemas.validators import TimeRangeMixin


class WeeklyTemplateBase(TimeRangeMixin):
    weekday: int = Field(..., ge=1, le=7)
    mode: OpeningModeEnum


class _EffectiveFromMixin(BaseModel):
    # The date from which a change to the standard hours reaches the opening_days
    # rows already generated. None means no propagation: the change only applies
    # to future generations.
    effective_from: date | None = None

    # Said by a caller that has been told what the change takes away from the
    # calendars already published on those days, and has answered for it.
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
