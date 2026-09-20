from collections.abc import Iterable, Sequence
from datetime import time

# A stretch of one lesson during which its teacher has another lesson too.
TimeSpan = tuple[time, time]


def _merged(spans: Iterable[TimeSpan]) -> list[TimeSpan]:
    merged: list[TimeSpan] = []

    for start, end in sorted(spans):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))

    return merged


# Stretches of [start, end) shared with any of others, merged, in order; touching is 0.
def overlaps_of(
    start: time,
    end: time,
    others: Sequence[TimeSpan],
) -> list[TimeSpan]:
    shared = []

    for other_start, other_end in others:
        clipped = (max(start, other_start), min(end, other_end))

        if clipped[0] < clipped[1]:
            shared.append(clipped)

    return _merged(shared)


# Whether the shared stretches leave part of the lesson to the pupil alone.
def is_partial(start: time, end: time, shared: Sequence[TimeSpan]) -> bool:
    return shared != [(start, end)]
