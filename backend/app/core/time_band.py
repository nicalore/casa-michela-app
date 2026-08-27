from datetime import time
from enum import StrEnum
from typing import Final

_OUTSIDE_DAY_ERROR: Final[str] = (
    "L'orario deve essere compreso fra le 06:00 e le 23:00."
)

_ACROSS_BANDS_ERROR: Final[str] = (
    "Una lezione non può essere separata in fasce orarie diverse."
)


# Mirrors frontend/lib/core/utils/time_bucket.dart, which draws these bands:
# the two files have to be changed together.
class TimeBandEnum(StrEnum):
    MORNING = "MORNING"
    AFTERNOON = "AFTERNOON"
    EVENING = "EVENING"


# Half-open: a band owns its start and hands its end to the next one, so
# 13:00 is the first minute of the afternoon rather than the last of the
# morning.
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


def assert_within_single_band(start_time: time, end_time: time) -> TimeBandEnum:
    band = band_of(start_time)
    _, band_end = band_bounds(band)

    if end_time > band_end:
        raise ValueError(_ACROSS_BANDS_ERROR)

    return band
