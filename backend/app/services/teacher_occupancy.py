from collections.abc import Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson

# The limit counts people, not lessons: a group hour of two fills the teacher.
MAX_CONCURRENT_STUDENTS: Final[int] = 2

_TOO_MANY_STUDENTS_ERROR: Final[str] = (
    "Non è possibile sovrapporre più di {maximum} lezioni."
)

# A remote hour is exclusive for its whole length.
_ONLINE_CANNOT_OVERLAP_ERROR: Final[str] = (
    "Le lezioni online non possono avere sovrapposizioni."
)

# (start, end, how many pupils it carries).
StudentSpan = tuple[time, time, int]


def students_of(lesson: Lesson) -> set[str]:
    return {link.booking.presence.student_tax_code for link in lesson.lesson_bookings}


def too_many_students_error() -> str:
    return _TOO_MANY_STUDENTS_ERROR.format(maximum=MAX_CONCURRENT_STUDENTS)


def online_cannot_overlap_error() -> str:
    return _ONLINE_CANNOT_OVERLAP_ERROR


# Summing weights is safe: a pupil cannot overlap themselves (checked
# elsewhere). (moment, delta) sorts closures first, so touching hours never overlap.
def peak_concurrent_students(spans: Sequence[StudentSpan]) -> int:
    events: list[tuple[time, int]] = []

    for start_time, end_time, students in spans:
        events.append((start_time, students))
        events.append((end_time, -students))

    events.sort()

    peak = 0
    current = 0

    for _, delta in events:
        current += delta
        peak = max(peak, current)

    return peak


def overlaps_an_online_hour(overlapping: Sequence[Lesson], *, mode: str) -> bool:
    if not overlapping:
        return False

    return mode == "online" or any(row.mode == "online" for row in overlapping)


# A lesson being rewritten must be excluded by the caller or it counts twice.
def spans_with(
    lessons: Sequence[Lesson],
    *,
    start_time: time,
    end_time: time,
    students: int,
) -> list[StudentSpan]:
    return [
        *((row.start_time, row.end_time, len(students_of(row))) for row in lessons),
        (start_time, end_time, students),
    ]
