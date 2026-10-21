from collections import defaultdict
from collections.abc import Iterable, Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson
from app.models.room import Room
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment

_OVER_CAPACITY_WARNING: Final[str] = (
    "La stanza {room} arriva a {peak} persone contemporaneamente, oltre la "
    "capienza dichiarata di {capacity}."
)


def teacher_of(lesson: Lesson) -> str:
    return lesson.availability.teacher_tax_code


# One day's rows, by teacher, in clock order.
def stretches_by_teacher(
    assignments: Iterable[TeacherRoomAssignment],
) -> dict[str, list[TeacherRoomAssignment]]:
    grouped: dict[str, list[TeacherRoomAssignment]] = defaultdict(list)

    for assignment in sorted(assignments, key=lambda row: row.start_time):
        grouped[assignment.teacher_tax_code].append(assignment)

    return dict(grouped)


# None before the first row or across a room change. Mirrors stretchAt in Dart.
def stretch_index(
    starts: Sequence[time],
    start_time: time,
    end_time: time,
) -> int | None:
    found = None

    for index, start in enumerate(starts):
        if start <= start_time:
            found = index
        elif start < end_time:
            return None
        else:
            break

    return found


def stretch_at(
    stretches: Sequence[TeacherRoomAssignment],
    start_time: time,
    end_time: time,
) -> TeacherRoomAssignment | None:
    index = stretch_index(
        [stretch.start_time for stretch in stretches],
        start_time,
        end_time,
    )

    return stretches[index] if index is not None else None


def room_of(
    lesson: Lesson,
    stretches: dict[str, list[TeacherRoomAssignment]],
) -> int | None:
    if lesson.teacher_mode != "presence":
        return None

    stretch = stretch_at(
        stretches.get(teacher_of(lesson), []),
        lesson.start_time,
        lesson.end_time,
    )

    return stretch.room_id if stretch is not None else None


def lessons_by_room(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
) -> dict[int, list[Lesson]]:
    stretches = stretches_by_teacher(assignments)
    grouped: dict[int, list[Lesson]] = defaultdict(list)

    for lesson in lessons:
        room_id = room_of(lesson, stretches)

        if room_id is not None:
            grouped[room_id].append(lesson)

    return dict(grouped)


# In-building teachers with a lesson in no single room.
def teachers_adrift(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
) -> set[str]:
    stretches = stretches_by_teacher(assignments)

    return {
        teacher_of(lesson)
        for lesson in lessons
        if lesson.teacher_mode == "presence" and room_of(lesson, stretches) is None
    }


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

    # A teacher counts as one head from first to last lesson, not per lesson.
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

    # Departures sort before arrivals at the same minute, so a back-to-back
    # handover is not counted twice.
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


# Merges adjacent as well as overlapping spans. Mirrors mergeSpans in
# frontend/lib/features/lessons/utils/timeline_geometry.dart.
def _merged(spans: Iterable[tuple[time, time]]) -> list[tuple[time, time]]:
    merged: list[tuple[time, time]] = []

    for start, end in sorted(spans):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))

            continue

        merged.append((start, end))

    return merged


def _left_open(
    occupied: Sequence[tuple[time, time]],
    covered: Sequence[tuple[time, time]],
) -> bool:
    shifts = _merged(covered)

    for start, end in _merged(occupied):
        reached = start

        for shift_start, shift_end in shifts:
            if shift_start > reached:
                break

            reached = max(reached, shift_end)

            if reached >= end:
                break

        if reached < end:
            return True

    return False


# A room is uncovered only where a non-supervisor teaches past every hour its
# supervisors teach; gaps and attività never count. Mirrors isRoomPlanSettled in
# frontend/lib/features/lessons/widgets/room_assignment_wizard.dart.
def rooms_left_open(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
    supervisions: Sequence[RoomSupervision],
) -> set[int]:
    stretches = stretches_by_teacher(assignments)
    watching = {
        (shift.room_id, shift.teacher_tax_code) for shift in supervisions
    }

    occupied: dict[int, list[tuple[time, time]]] = defaultdict(list)
    covered: dict[int, list[tuple[time, time]]] = defaultdict(list)

    for lesson in lessons:
        room_id = room_of(lesson, stretches)

        if room_id is None:
            continue

        teacher = teacher_of(lesson)

        occupied[room_id].append((lesson.start_time, lesson.end_time))

        if (room_id, teacher) in watching:
            covered[room_id].append((lesson.start_time, lesson.end_time))

    return {
        room_id
        for room_id, hours in occupied.items()
        if _left_open(hours, covered.get(room_id, []))
    }


def teachers_in_building(lessons: Sequence[Lesson]) -> set[str]:
    return {
        teacher_of(lesson)
        for lesson in lessons
        if lesson.teacher_mode == "presence"
    }
