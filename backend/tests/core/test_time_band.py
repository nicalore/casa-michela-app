from datetime import time

import pytest

from app.core.time_band import (
    TimeBandEnum,
    assert_within_single_band,
    band_of,
)

# The same bounds the client draws, in frontend/lib/core/utils/time_bucket.dart.
# If one side moves, this is where the other finds out.


@pytest.mark.parametrize(
    ("moment", "expected"),
    [
        (time(6), TimeBandEnum.MORNING),
        (time(12, 59), TimeBandEnum.MORNING),
        (time(13), TimeBandEnum.AFTERNOON),
        (time(18, 59), TimeBandEnum.AFTERNOON),
        (time(19), TimeBandEnum.EVENING),
        (time(22, 59), TimeBandEnum.EVENING),
    ],
)
def test_band_boundaries_are_half_open(moment: time, expected: TimeBandEnum) -> None:
    assert band_of(moment) is expected


@pytest.mark.parametrize("moment", [time(5, 59), time(23), time(23, 30)])
def test_outside_the_day_is_refused(moment: time) -> None:
    with pytest.raises(ValueError, match="06:00"):
        band_of(moment)


# Noon to one is entirely morning: a band hands its end to the next one, so
# touching the boundary from the left is still inside.
def test_a_lesson_may_end_exactly_on_the_boundary() -> None:
    assert assert_within_single_band(time(12), time(13)) is TimeBandEnum.MORNING


def test_a_lesson_may_not_cross_the_boundary() -> None:
    with pytest.raises(ValueError, match="fasce"):
        assert_within_single_band(time(12, 30), time(13, 30))
