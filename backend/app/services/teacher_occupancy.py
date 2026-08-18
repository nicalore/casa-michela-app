from collections.abc import Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson

# The limit is on people and not on rows: overlapping lessons are legitimate at
# a doposcuola, but a group hour of two already fills the teacher up.
MAX_CONCURRENT_STUDENTS: Final[int] = 2

_TOO_MANY_STUDENTS_ERROR: Final[str] = (
    "Non è possibile sovrapporre più di {maximum} lezioni."
)

# A remote hour is alone for its whole length: a teacher in a call cannot turn
# from it to somebody sitting beside them.
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


# The busiest moment of a teacher's day, in pupils. Summing the weights is safe
# because the same pupil cannot be in two overlapping lessons — a rule of its
# own, checked beside this one.
#
# Sorting by (moment, delta) puts closures before openings at the same instant,
# so an hour ending at 15:00 and one starting at 15:00 do not overlap.
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


# Whether any of these overlapping hours is remote, the new one included. With
# nothing to overlap there is nothing to refuse, whatever mode it is in.
def overlaps_an_online_hour(overlapping: Sequence[Lesson], *, mode: str) -> bool:
    if not overlapping:
        return False

    return mode == "online" or any(row.mode == "online" for row in overlapping)


# The stored spans plus the one being written. A lesson being rewritten has to
# have been left out by the caller, or it is counted twice.
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
