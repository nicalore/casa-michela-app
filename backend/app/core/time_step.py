from datetime import time
from typing import Final

_TIME_STEP_MINUTES: Final[int] = 15

# Half an hour is the shortest stretch worth teaching in: anything less is a
# pupil arriving and leaving.
MINIMUM_BAND_MINUTES: Final[int] = 30

_TIME_STEP_ERROR: Final[str] = (
    "L'orario deve essere espresso in multipli di 15 minuti."
)


def assert_quarter_hour_step(value: time) -> time:
    if value.minute % _TIME_STEP_MINUTES != 0:
        raise ValueError(_TIME_STEP_ERROR)

    return value


def minutes_between(start: time, end: time) -> int:
    return (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)
