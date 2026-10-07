from datetime import time
from enum import StrEnum
from typing import Final

_OUTSIDE_DAY_ERROR: Final[str] = (
    "L'orario deve essere compreso fra le 06:00 e le 23:00."
)

_ACROSS_BANDS_ERROR: Final[str] = (
    "Una lezione non può essere separata in fasce orarie diverse."
)

_PRESENCE_ACROSS_BANDS_ERROR: Final[str] = (
    "Un orario di presenza non può stare a cavallo di due fasce orarie."
)


# Mirrors frontend/lib/core/utils/time_bucket.dart, which draws these bands:
# the two files have to be changed together.
class TimeBandEnum(StrEnum):
    MORNING = "MORNING"
    AFTERNOON = "AFTERNOON"
    EVENING = "EVENING"


# Half-open: 13:00 is the first minute of the afternoon, not the last of the morning.
DAY_START: Final[time] = time(6)
AFTERNOON_START: Final[time] = time(13)
EVENING_START: Final[time] = time(19)
DAY_END: Final[time] = time(23)

_BAND_BOUNDS: Final[dict[TimeBandEnum, tuple[time, time]]] = {
    TimeBandEnum.MORNING: (DAY_START, AFTERNOON_START),
    TimeBandEnum.AFTERNOON: (AFTERNOON_START, EVENING_START),
    TimeBandEnum.EVENING: (EVENING_START, DAY_END),
}


def band_of(moment: time) -> TimeBandEnum:
    if moment < DAY_START or moment >= DAY_END:
        raise ValueError(_OUTSIDE_DAY_ERROR)

    if moment < AFTERNOON_START:
        return TimeBandEnum.MORNING

    if moment < EVENING_START:
        return TimeBandEnum.AFTERNOON

    return TimeBandEnum.EVENING


def band_bounds(band: TimeBandEnum) -> tuple[time, time]:
    return _BAND_BOUNDS[band]


def assert_within_single_band(
    start_time: time,
    end_time: time,
    *,
    error: str = _ACROSS_BANDS_ERROR,
) -> TimeBandEnum:
    band = band_of(start_time)
    _, band_end = band_bounds(band)

    if end_time > band_end:
        raise ValueError(error)

    return band


# A pupil's stretch, and the subjects booked under it, belong to one band.
def presence_band(start_time: time, end_time: time) -> TimeBandEnum:
    return assert_within_single_band(
        start_time,
        end_time,
        error=_PRESENCE_ACROSS_BANDS_ERROR,
    )
