from collections.abc import Iterable
from datetime import time
from typing import Final

_TIME_STEP_MINUTES: Final[int] = 15

# Half an hour is the shortest stretch a pupil stays for.
MINIMUM_BAND_MINUTES: Final[int] = 30

# A lesson lasts half an hour too, or a quarter hour when that is its whole booking.
MINIMUM_LESSON_MINUTES: Final[int] = 30
QUARTER_LESSON_MINUTES: Final[int] = 15

_TIME_STEP_ERROR: Final[str] = (
    "L'orario deve essere espresso in multipli di 15 minuti."
)


def assert_quarter_hour_step(value: time) -> time:
    if value.minute % _TIME_STEP_MINUTES != 0:
        raise ValueError(_TIME_STEP_ERROR)

    return value


def minutes_between(start: time, end: time) -> int:
    return (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)


# Whole, not merely touching: a lesson cannot straddle the gap between stretches.
def fits_a_window(
    start: time,
    end: time,
    windows: Iterable[tuple[time, time]],
) -> bool:
    return any(
        window_start <= start and end <= window_end
        for window_start, window_end in windows
    )
