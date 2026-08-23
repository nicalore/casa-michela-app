from collections.abc import Iterable
from datetime import date, datetime, time, timedelta
from typing import Final
from zoneinfo import ZoneInfo

from app.core.labels import time_band_label
from app.core.time_band import TimeBandEnum, band_bounds

_ROME_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

# Mirrors _closingTimes in frontend/lib/core/utils/time_bucket.dart, which
# only decides what to draw while this side enforces it.
_CLOSING_TIMES: Final[dict[TimeBandEnum, tuple[int, time]]] = {
    TimeBandEnum.MORNING: (1, time(20)),
    TimeBandEnum.AFTERNOON: (0, time(11)),
    TimeBandEnum.EVENING: (0, time(18)),
}

_TOO_EARLY_ERROR: Final[str] = (
    "Il calendario di {band} del {day} si può pubblicare dal {opens}, quando "
    "chiudono le prenotazioni."
)

_CLOSED_ERROR: Final[str] = (
    "Le prenotazioni di {band} del {day} si sono chiuse il {closed}: da qui in "
    "avanti solo un amministratore può modificarle."
)


def _format(moment: datetime) -> str:
    return moment.strftime("%d/%m/%Y alle %H:%M")


def _day_label(day: date) -> str:
    return day.strftime("%d/%m/%Y")


def closes_at(day: date, band: TimeBandEnum) -> datetime:
    days_before, hour = _CLOSING_TIMES[band]

    return datetime.combine(
        day - timedelta(days=days_before),
        hour,
        tzinfo=_ROME_TIMEZONE,
    )


def now_in_rome() -> datetime:
    return datetime.now(_ROME_TIMEZONE)


def has_closed(day: date, band: TimeBandEnum, now: datetime) -> bool:
    return now >= closes_at(day, band)


def bands_of(start_time: time, end_time: time) -> set[TimeBandEnum]:
    return {
        band
        for band in TimeBandEnum
        if start_time < band_bounds(band)[1] and end_time > band_bounds(band)[0]
    }


def assert_ready_to_publish(day: date, band: TimeBandEnum, now: datetime) -> None:
    if has_closed(day, band, now):
        return

    raise ValueError(
        _TOO_EARLY_ERROR.format(
            band=time_band_label(str(band)).lower(),
            day=_day_label(day),
            opens=_format(closes_at(day, band)),
        ),
    )


def assert_still_open(
    day: date,
    bands: Iterable[TimeBandEnum],
    *,
    is_admin: bool,
    now: datetime | None = None,
) -> None:
    if is_admin:
        return

    moment = now or now_in_rome()

    for band in sorted(bands, key=lambda row: closes_at(day, row)):
        if has_closed(day, band, moment):
            raise ValueError(
                _CLOSED_ERROR.format(
                    band=time_band_label(str(band)).lower(),
                    day=_day_label(day),
                    closed=_format(closes_at(day, band)),
                ),
            )
