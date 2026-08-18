from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta
from typing import Final

from fastapi import HTTPException, status

from app.core.booking_window import today_in_rome
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.models.opening_day import OpeningDay
from app.models.weekly_template import WeeklyTemplate
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.schemas.weekly_template import WeeklyTemplateCreate, WeeklyTemplateUpdate
from app.services.availability_cleanup import purge_availabilities_for_closed_days

_ENTITY_LABEL: Final[str] = "il template settimanale"
_NOT_FOUND_ERROR: Final[str] = "Riga di template non trovata"
_CREATE_ERROR: Final[str] = "Errore durante la creazione della riga di template."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_DAYS_IN_WEEK: Final[int] = 7


class WeeklyTemplateService:
    def __init__(
        self,
        repository: WeeklyTemplateRepository,
        opening_day_repository: OpeningDayRepository,
    ) -> None:
        self.repository = repository
        self.opening_day_repository = opening_day_repository

    async def list_all(self) -> Sequence[WeeklyTemplate]:
        return await self.repository.list()

    async def get_or_404(self, template_id: int) -> WeeklyTemplate:
        template = await self.repository.get_by_id(template_id)

        if template is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return template

    # Propagation reaches the last generated date and no further: the horizon
    # belongs to generate_opening_days, and days invented past it would come out
    # open on holidays never seeded. Beyond it nothing needs doing — the next
    # generation already reads the updated templates.
    async def _propagation_horizon(self, mode: str) -> date | None:
        return await self.opening_day_repository.last_generated_date(mode)

    def _matching_dates(
        self,
        *,
        weekday: int,
        effective_from: date,
        horizon: date,
        overridden: set[date],
    ) -> list[date]:
        # Aligned onto the first matching weekday instead of walking the six
        # days that cannot match.
        current = effective_from + timedelta(
            days=(weekday - effective_from.isoweekday()) % _DAYS_IN_WEEK
        )

        dates: list[date] = []

        while current <= horizon:
            if current not in overridden:
                dates.append(current)

            current += timedelta(days=_DAYS_IN_WEEK)

        return dates

    # Rewrites the days of that weekday from that date on.
    #
    # The whole day and not the rows a change is recognised by: a band that
    # changed its start time used to leave its old rows behind. Idempotent too,
    # since whatever was there is deleted before the reinsert.
    #
    # Overrides stay untouched: holidays, closures and extraordinary openings do
    # not come from the templates and take precedence.
    async def reconcile_weekday(
        self,
        *,
        weekday: int,
        mode: str,
        effective_from: date,
    ) -> None:
        horizon = await self._propagation_horizon(mode)

        if horizon is None or horizon < effective_from:
            # Nothing materialised in that window: the next
            # generate_opening_days will handle it, reading the new templates.
            return

        overridden = await self.opening_day_repository.dates_with_override(
            mode=mode,
            date_from=effective_from,
            date_to=horizon,
        )

        dates = self._matching_dates(
            weekday=weekday,
            effective_from=effective_from,
            horizon=horizon,
            overridden=overridden,
        )

        if not dates:
            return

        templates = [
            template
            for template in await self.repository.list_by_weekday(weekday)
            if template.mode == mode
        ]

        await self.opening_day_repository.delete_generated_for_dates(dates, mode)

        await self.opening_day_repository.create_many([
            OpeningDay(
                date=day,
                mode=mode,
                start_time=template.start_time,
                end_time=template.end_time,
                is_override=False,
            )
            for day in dates
            for template in templates
            # A rule only applies from its effective date on.
            if template.effective_from <= day
        ])

        # A day left with no band is a closed day, and an availability is an
        # offer to be there while the association is open.
        await purge_availabilities_for_closed_days(
            self.opening_day_repository.session,
            dates,
            mode,
        )

    # Withdraws a band. The rows already materialised are rewritten by the
    # weekday reconcile, which reads the templates that are left.
    async def _discard_slot(
        self,
        *,
        template: WeeklyTemplate,
        effective_from: date | None,
    ) -> None:
        weekday = template.weekday
        mode = template.mode

        await self.repository.delete(template)

        if effective_from is not None:
            await self.reconcile_weekday(
                weekday=weekday,
                mode=mode,
                effective_from=effective_from,
            )

    async def create(self, payload: WeeklyTemplateCreate) -> WeeklyTemplate:
        # The effective date is a property of the rule and not just a parameter
        # of the request: without it, next year's generation would apply from
        # 1 January an opening decided for March.
        rule_start = payload.effective_from or today_in_rome()

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            # (weekday, mode, start_time) is unique: if that time already
            # exists, "adding" it means overwriting it rather than failing. The
            # reconcile below rewrites the whole day anyway, so the template row
            # is all that is needed here.
            existing = await self.repository.get_by_slot(
                payload.weekday, payload.mode.value, payload.start_time
            )

            if existing is not None:
                existing.end_time = payload.end_time
                existing.effective_from = rule_start
                template = existing
            else:
                template = WeeklyTemplate(
                    weekday=payload.weekday,
                    mode=payload.mode.value,
                    start_time=payload.start_time,
                    end_time=payload.end_time,
                    effective_from=rule_start,
                )
                await self.repository.create(template)

            if payload.effective_from is not None:
                await self.reconcile_weekday(
                    weekday=payload.weekday,
                    mode=payload.mode.value,
                    effective_from=payload.effective_from,
                )

            await self.repository.commit()
            await self.repository.refresh(template)

        return template

    async def update(
        self,
        template_id: int,
        payload: WeeklyTemplateUpdate,
    ) -> WeeklyTemplate:
        template = await self.get_or_404(template_id)

        assert_not_stale(
            template,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        # weekday/mode are immutable: they stay stable to identify the
        # opening_days rows produced by this template row.
        old_start_time = template.start_time
        weekday = template.weekday
        mode = template.mode

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            # Moving a band onto a time another row of the same day holds
            # overwrites it, so that row has to be withdrawn first or the unique
            # constraint is hit. Without an effective date, since the reconcile
            # below rewrites the day anyway.
            if payload.start_time != old_start_time:
                clashing = await self.repository.get_by_slot(
                    weekday, mode, payload.start_time
                )

                if clashing is not None and clashing.id != template.id:
                    await self._discard_slot(template=clashing, effective_from=None)

            template.start_time = payload.start_time
            template.end_time = payload.end_time

            if payload.effective_from is not None:
                template.effective_from = payload.effective_from

            # The template row changed, so the day is rewritten from scratch and
            # the rows of the band as it was disappear with it. Without an
            # effective date the historical default applies, from tomorrow on:
            # what has already passed is left alone.
            await self.reconcile_weekday(
                weekday=weekday,
                mode=mode,
                effective_from=(
                    payload.effective_from or today_in_rome() + timedelta(days=1)
                ),
            )

            await self.repository.commit()
            # updated_at has a server-side onupdate: after the UPDATE is flushed
            # the attribute stays expired, and serialising the response would
            # attempt a lazy load outside the async context (MissingGreenlet).
            await self.repository.refresh(template)

        return template

    async def delete(
        self,
        template_id: int,
        effective_from: date | None = None,
    ) -> None:
        # No cascade towards opening_days: there is no FK, by design. Without
        # effective_from the deletion only affects the next
        # generate_opening_days; with it, the rows already generated from that
        # date on are withdrawn too, leaving the overrides intact.
        template = await self.get_or_404(template_id)

        await self._discard_slot(template=template, effective_from=effective_from)
        await self.repository.commit()
