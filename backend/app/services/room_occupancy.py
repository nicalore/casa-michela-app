from collections import defaultdict
from collections.abc import Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson
from app.models.room import Room
from app.models.teacher_room_assignment import TeacherRoomAssignment

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


def peak_occupancy(lessons: Sequence[Lesson]) -> int:
    if not lessons:
        return 0

    spans: dict[str, list[Lesson]] = defaultdict(list)

    for lesson in lessons:
        spans[teacher_of(lesson)].append(lesson)

    events: list[tuple[time, int]] = []

    # A teacher is one head from their first lesson to their last, not one per
    # lesson: they do not leave the room between two of their own hours.
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

    # Ties break on the delta, so departures land before arrivals at the same
    # minute and a back-to-back handover is not counted twice.
    events.sort(key=lambda event: (event[0], event[1]))

    peak = 0
    current = 0

    for _, delta in events:
        current += delta
        peak = max(peak, current)

    return peak


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


def teachers_in_building(lessons: Sequence[Lesson]) -> set[str]:
    return {
        teacher_of(lesson)
        for lesson in lessons
        if lesson.teacher_mode == "presence"
    }
