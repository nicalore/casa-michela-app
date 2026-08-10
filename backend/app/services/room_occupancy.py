from collections import defaultdict
from collections.abc import Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson
from app.models.room import Room
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment

# How full a room gets and whether anybody is watching it. Both answers are read
# off the same three lists — the lessons of a day, who has which room, and who
# is on shift — and both are needed twice: while the rooms are being handed out,
# and again when the band is published.

_OVER_CAPACITY_WARNING: Final[str] = (
    "La stanza {room} arriva a {peak} persone contemporaneamente, oltre la "
    "capienza dichiarata di {capacity}."
)


def teacher_of(lesson: Lesson) -> str:
    return lesson.availability.teacher_tax_code


def rooms_by_teacher(
    assignments: Sequence[TeacherRoomAssignment],
) -> dict[str, int]:
    return {
        assignment.teacher_tax_code: assignment.room_id
        for assignment in assignments
    }


# Only lessons taught from the building take up a room. A teacher working from
# home has no room to be in, and their lessons belong to no room here.
def lessons_by_room(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
) -> dict[int, list[Lesson]]:
    rooms = rooms_by_teacher(assignments)
    grouped: dict[int, list[Lesson]] = defaultdict(list)

    for lesson in lessons:
        if lesson.teacher_mode != "presence":
            continue

        room_id = rooms.get(teacher_of(lesson))

        if room_id is not None:
            grouped[room_id].append(lesson)

    return dict(grouped)


def students_of(lesson: Lesson) -> set[str]:
    return {
        link.booking.presence.student_tax_code for link in lesson.lesson_bookings
    }


# The busiest moment of a room, by a sweep over the hours.
#
# A teacher counts as one person for the whole span of their own lessons —
# they do not leave the room between two of them — while pupils count only
# where they are actually in it: someone joining from home takes up no chair.
def peak_occupancy(lessons: Sequence[Lesson]) -> int:
    if not lessons:
        return 0

    spans: dict[str, list[Lesson]] = defaultdict(list)

    for lesson in lessons:
        spans[teacher_of(lesson)].append(lesson)

    events: list[tuple[time, int]] = []

    for teacher_lessons in spans.values():
        events.append((min(row.start_time for row in teacher_lessons), 1))
        events.append((max(row.end_time for row in teacher_lessons), -1))

    for lesson in lessons:
        if lesson.mode != "presence":
            continue

        heads = len(students_of(lesson))

        if heads:
            events.append((lesson.start_time, heads))
            events.append((lesson.end_time, -heads))

    # Departures before arrivals at the same minute: one lesson ending as
    # another begins is a handover, not a crowd.
    events.sort(key=lambda event: (event[0], event[1]))

    peak = 0
    current = 0

    for _, delta in events:
        current += delta
        peak = max(peak, current)

    return peak


# Said and never enforced: capacity is optional to begin with, and nobody should
# be stopped from publishing by a number that was never taken.
def capacity_warnings(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
    rooms: dict[int, Room],
) -> list[str]:
    warnings = []

    for room_id, room_lessons in lessons_by_room(lessons, assignments).items():
        room = rooms.get(room_id)

        if room is None or room.capacity is None:
            continue

        peak = peak_occupancy(room_lessons)

        if peak > room.capacity:
            warnings.append(
                _OVER_CAPACITY_WARNING.format(
                    room=room.name,
                    peak=peak,
                    capacity=room.capacity,
                ),
            )

    return warnings


# The stretch a room has to be watched over: from the first lesson in it to the
# last. Nothing to watch over means nothing to arrange.
def watched_span(lessons: Sequence[Lesson]) -> tuple[time, time] | None:
    if not lessons:
        return None

    return (
        min(lesson.start_time for lesson in lessons),
        max(lesson.end_time for lesson in lessons),
    )


# Where the shifts leave the room alone. Returns the first uncovered moment, or
# None when the cover is continuous: the shifts are merged in order and any
# daylight between one and the next is a gap.
def coverage_gap(
    lessons: Sequence[Lesson],
    supervisions: Sequence[RoomSupervision],
) -> tuple[time, time] | None:
    span = watched_span(lessons)

    if span is None:
        return None

    start, end = span
    reached = start

    for shift in sorted(supervisions, key=lambda row: row.start_time):
        if shift.start_time > reached:
            return (reached, shift.start_time)

        reached = max(reached, shift.end_time)

        if reached >= end:
            return None

    if reached < end:
        return (reached, end)

    return None


# Who has to have a room: the teachers actually in the building. Someone
# teaching from home is convened but occupies nothing.
def teachers_in_building(lessons: Sequence[Lesson]) -> set[str]:
    return {
        teacher_of(lesson)
        for lesson in lessons
        if lesson.teacher_mode == "presence"
    }
