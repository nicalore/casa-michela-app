from collections.abc import Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson
from app.models.study_program import EducationLevelEnum

# The limit counts people, not lessons: a group hour of two fills the teacher.
MAX_CONCURRENT_STUDENTS: Final[int] = 2

# Pupils at these levels may crowd past the limit, as long as nobody else is there.
UNCAPPED_LEVELS: Final[frozenset[EducationLevelEnum]] = frozenset(
    {EducationLevelEnum.PRIMARY_SCHOOL, EducationLevelEnum.MIDDLE_SCHOOL},
)

_TOO_MANY_STUDENTS_ERROR: Final[str] = (
    "Non è possibile sovrapporre più di due lezioni con gli studenti delle superiori."
)

# A remote hour is exclusive for its whole length.
_ONLINE_CANNOT_OVERLAP_ERROR: Final[str] = (
    "Le lezioni online non possono avere sovrapposizioni."
)

# (start, end, how many pupils it carries, how many of them keep the limit).
StudentSpan = tuple[time, time, int, int]


def students_of(lesson: Lesson) -> set[str]:
    return {link.booking.presence.student_tax_code for link in lesson.lesson_bookings}


def too_many_students_error() -> str:
    return _TOO_MANY_STUDENTS_ERROR


def online_cannot_overlap_error() -> str:
    return _ONLINE_CANNOT_OVERLAP_ERROR


# Summing weights is safe: a pupil cannot overlap themselves (checked
# elsewhere). Closures sort first, so touching hours never overlap.
def overcrowded(spans: Sequence[StudentSpan]) -> bool:
    events: list[tuple[time, int, int]] = []

    for start_time, end_time, students, capped in spans:
        events.append((start_time, students, capped))
        events.append((end_time, -students, -capped))

    events.sort()

    current = 0
    current_capped = 0

    for _, delta, capped_delta in events:
        current += delta
        current_capped += capped_delta

        if current > MAX_CONCURRENT_STUDENTS and current_capped > 0:
            return True

    return False


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
    students: set[str],
    uncapped: set[str],
) -> list[StudentSpan]:
    def span(start: time, end: time, pupils: set[str]) -> StudentSpan:
        return (start, end, len(pupils), len(pupils - uncapped))

    return [
        *(span(row.start_time, row.end_time, students_of(row)) for row in lessons),
        span(start_time, end_time, students),
    ]
