from datetime import time
from enum import StrEnum
from typing import Final

_OUTSIDE_DAY_ERROR: Final[str] = (
    "L'orario deve essere compreso fra le 06:00 e le 23:00."
)

_ACROSS_BANDS_ERROR: Final[str] = (
    "Una lezione non può attraversare due fasce della giornata: "
    "mattino, pomeriggio e sera si pubblicano separatamente."
)


# The three parts the association's day is divided into. The bounds mirror
# frontend/lib/core/utils/time_bucket.dart, which draws them; the two files have
# to be changed together, exactly as booking_window.py and booking_window.dart
# already do.
#
# Not to be confused with the "bands" of opening_window.py, which are the
# contiguous stretches an opening day is made of: those are data the association
# edits, these three are fixed and a lesson belongs to exactly one of them.
class TimeBandEnum(StrEnum):
    MORNING = "MORNING"
    AFTERNOON = "AFTERNOON"
    EVENING = "EVENING"


# Half-open: a band owns its start and hands its end to the next one, so 13:00
# is the first minute of the afternoon rather than the last of the morning.
#
# The outer bounds are far wider than any opening the association has ever had,
# and deliberately so: they exist to let the hours move without the code moving
# with them.
DAY_START: Final[time] = time(6)
AFTERNOON_START: Final[time] = time(13)
EVENING_START: Final[time] = time(19)
DAY_END: Final[time] = time(23)

_BAND_BOUNDS: Final[dict[TimeBandEnum, tuple[time, time]]] = {
    TimeBandEnum.MORNING: (DAY_START, AFTERNOON_START),
    TimeBandEnum.AFTERNOON: (AFTERNOON_START, EVENING_START),
    TimeBandEnum.EVENING: (EVENING_START, DAY_END),
}


# Which band a moment belongs to. Total over the day the CHECK constraints
# admit, and a ValueError outside it: reached through a service, that becomes a
# 400 naming the hour, instead of the integrity error the database would raise
# one step later.
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


# A stretch that starts in one band and ends in another is not publishable:
# half a lesson visible and half not says nothing to anybody. The end is
# compared against the band's own end and allowed to touch it, because the
# bands are half-open — 12:00 to 13:00 is entirely morning.
def assert_within_single_band(start_time: time, end_time: time) -> TimeBandEnum:
    band = band_of(start_time)
    _, band_end = band_bounds(band)

    if end_time > band_end:
        raise ValueError(_ACROSS_BANDS_ERROR)

    return band
