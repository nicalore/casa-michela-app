from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta
from typing import Final

from fastapi import HTTPException, status

from app.core.holidays import holiday_label
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.models.opening_day import OpeningDay
from app.repositories.opening_day_repository import OpeningDayRepository
from app.repositories.weekly_template_repository import WeeklyTemplateRepository
from app.schemas.opening_day import (
    OpeningDayCreate,
    OpeningDayReplace,
    OpeningDayUpdate,
)
from app.services.availability_cleanup import (
    PurgedHours,
    purge_hours_outside_openings,
)
from app.services.calendar_hours_sync import CalendarHoursWatch

_ENTITY_LABEL: Final[str] = "le aperture"
_NOT_FOUND_ERROR: Final[str] = "Apertura non trovata"
_CREATE_ERROR: Final[str] = "Errore durante la creazione dell'apertura."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."
_RESTORE_ERROR: Final[str] = "Errore durante il ripristino dell'orario standard."


class OpeningDayService:
    def __init__(
        self,
        repository: OpeningDayRepository,
        weekly_template_repository: WeeklyTemplateRepository,
    ) -> None:
        self.repository = repository
        self.weekly_template_repository = weekly_template_repository

    async def list_for(
        self,
        *,
        date_from: date | None,
        date_to: date | None,
        mode: str | None,
    ) -> Sequence[OpeningDay]:
        return await self.repository.list(
            date_from=date_from,
            date_to=date_to,
            mode=mode,
        )

    async def get_or_404(self, opening_day_id: int) -> OpeningDay:
        opening_day = await self.repository.get_by_id(opening_day_id)

        if opening_day is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return opening_day

    async def create(self, payload: OpeningDayCreate) -> OpeningDay:
        # Every row written through the API is by definition a manual touch by
        # an admin: is_override is never accepted from the client.
        opening_day = OpeningDay(
            date=payload.date,
            mode=payload.mode.value,
            start_time=payload.start_time,
            end_time=payload.end_time,
            is_override=True,
            note=payload.note,
        )

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            watch = await self._watch([opening_day.date])

            await self.repository.create(opening_day)
            purged = await self._purge_closed([opening_day.date], opening_day.mode)
            await watch.settle(purged=purged)
            await self.repository.commit()

        return opening_day

    # A day's hours written whole: the rows of that day and mode are replaced by
    # the bands given, and no bands at all is the day being closed.
    #
    # One call and one transaction, which is what makes the difference between
    # changing a day's hours and closing it: written row by row, a change passes
    # through a moment with no hours on the day, and a day with no hours is one
    # whose lessons are cleared and whose calendar is taken down.
    async def replace_day(self, payload: OpeningDayReplace) -> list[OpeningDay]:
        mode = payload.mode.value
        day = payload.date

        rows = [
            OpeningDay(
                date=day,
                mode=mode,
                start_time=band.start_time,
                end_time=band.end_time,
                is_override=True,
                note=payload.note,
            )
            for band in payload.bands
        ] or [
            OpeningDay(
                date=day,
                mode=mode,
                start_time=None,
                end_time=None,
                is_override=True,
                note=payload.note,
            )
        ]

        async with integrity_guard(self.repository.session, _CREATE_ERROR):
            watch = await self._watch([day])

            await self.repository.delete_for_range_mode(
                date_from=day,
                date_to=day,
                mode=mode,
            )
            await self.repository.create_many(rows)
            purged = await self._purge_closed([day], mode)
            await watch.settle(confirmed=payload.confirm, purged=purged)
            await self.repository.commit()

        return rows

    async def update(
        self,
        opening_day_id: int,
        payload: OpeningDayUpdate,
    ) -> OpeningDay:
        opening_day = await self.get_or_404(opening_day_id)

        assert_not_stale(
            opening_day,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        # Read before the row is touched: a query made after it would autoflush
        # the new hours and find them already in place.
        watch = await self._watch([opening_day.date])

        opening_day.start_time = payload.start_time
        opening_day.end_time = payload.end_time
        opening_day.note = payload.note
        opening_day.is_override = True

        async with integrity_guard(self.repository.session, _UPDATE_ERROR):
            await self.repository.session.flush()
            purged = await self._purge_closed([opening_day.date], opening_day.mode)
            await watch.settle(confirmed=payload.confirm, purged=purged)
            await self.repository.commit()
            # updated_at has a server-side onupdate: after the UPDATE is flushed
            # the attribute stays expired, and serialising the response would
            # attempt a lazy load outside the async context (MissingGreenlet).
            await self.repository.refresh(opening_day)

        return opening_day

    async def delete(self, opening_day_id: int, *, confirmed: bool = False) -> None:
        opening_day = await self.get_or_404(opening_day_id)
        target_date = opening_day.date
        mode = opening_day.mode

        watch = await self._watch([target_date])

        await self.repository.delete(opening_day)
        purged = await self._purge_closed([target_date], mode)
        await watch.settle(confirmed=confirmed, purged=purged)
        await self.repository.commit()

    # Every way of writing the calendar ends here: an hour offered or booked
    # against the old opening and left outside the new one goes, and a date with
    # no opening left is only the widest case of that.
    async def _purge_closed(self, dates: Sequence[date], mode: str) -> PurgedHours:
        return await purge_hours_outside_openings(
            self.repository.session,
            dates,
            mode,
        )

    # And here: a band whose hours moved sends its calendar back into bozza, and
    # one left with no hours at all loses it. Taken before the write and settled
    # after it, so what it compares is the change itself.
    async def _watch(self, dates: Sequence[date]) -> CalendarHoursWatch:
        return await CalendarHoursWatch.taken(self.repository.session, dates)

    async def _standard_rows_for(
        self,
        dates: Sequence[date],
        mode: str,
    ) -> list[OpeningDay]:
        templates_by_weekday = {
            weekday: [
                template
                for template in await self.weekly_template_repository.list_by_weekday(
                    weekday
                )
                if template.mode == mode
            ]
            for weekday in range(1, 8)
        }

        rows: list[OpeningDay] = []

        for current in dates:
            label = holiday_label(current)

            # Holidays stay holidays: on those dates the closure is rewritten
            # with the name of the recurrence rather than the template hours,
            # otherwise undoing a special opening on a holiday would leave the
            # association open.
            if label is not None:
                rows.append(
                    OpeningDay(
                        date=current,
                        mode=mode,
                        start_time=None,
                        end_time=None,
                        is_override=True,
                        note=label,
                    )
                )
                continue

            rows.extend(
                OpeningDay(
                    date=current,
                    mode=mode,
                    start_time=template.start_time,
                    end_time=template.end_time,
                    is_override=False,
                )
                for template in templates_by_weekday[current.isoweekday()]
                # A rule only applies from its effective date on.
                if template.effective_from <= current
            )

        return rows

    # Brings a range back to the standard hours, discarding the variations: the
    # inverse of an extraordinary closure or opening. The rows of those dates are
    # deleted and rewritten from the weekly templates with is_override False, so
    # the days become indistinguishable from generated ones — deleting alone
    # would leave them with no band at all, that is neither open nor closed.
    #
    # It stops at the last already materialised date, like template propagation
    # does: beyond that horizon the calendar does not exist yet, and writing it
    # from here would produce days whose holidays were never seeded.
    #
    # Returns (restored days, rows written).
    async def restore_standard(
        self,
        *,
        date_from: date,
        date_to: date,
        mode: str,
        confirmed: bool = False,
    ) -> tuple[int, int]:
        # Read before the deletion: afterwards the horizon could be one of the
        # very dates being removed.
        horizon = await self.repository.last_generated_date(mode)

        watch = await self._watch([
            date_from + timedelta(days=offset)
            for offset in range((date_to - date_from).days + 1)
        ])

        await self.repository.delete_for_range_mode(
            date_from=date_from,
            date_to=date_to,
            mode=mode,
        )

        if horizon is None:
            # Nothing materialised for this mode: there is no standard to
            # rewrite, and inventing one here would be generation.
            last_date = date_from - timedelta(days=1)
        else:
            last_date = min(date_to, horizon)

        restored_dates = [
            date_from + timedelta(days=offset)
            for offset in range((last_date - date_from).days + 1)
        ]

        to_create = await self._standard_rows_for(restored_dates, mode)

        async with integrity_guard(self.repository.session, _RESTORE_ERROR):
            await self.repository.create_many(to_create)

            # Going back to the standard hours can shut a day a special opening
            # had opened, or narrow it: what was given against the opening that
            # is gone goes with it.
            purged = await self._purge_closed(restored_dates, mode)
            await watch.settle(confirmed=confirmed, purged=purged)
            await self.repository.commit()

        return len(restored_dates), len(to_create)
