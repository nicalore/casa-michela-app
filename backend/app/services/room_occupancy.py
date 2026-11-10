from collections import defaultdict
from collections.abc import Iterable, Sequence
from datetime import time
from typing import Final

from app.models.lesson import Lesson
from app.models.room import Room
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment

_Span = tuple[time, time]

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


# Teachers with a lesson in person in no single room. An online lesson needs no
# room, even taught from the association.
def teachers_adrift(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
) -> set[str]:
    stretches = stretches_by_teacher(assignments)

    return {
        teacher_of(lesson)
        for lesson in lessons
        if lesson.mode == "presence" and room_of(lesson, stretches) is None
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
def _merged(spans: Iterable[_Span]) -> list[_Span]:
    merged: list[_Span] = []

    for start, end in sorted(spans):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))

            continue

        merged.append((start, end))

    return merged


# Whether merged spans run unbroken from start to end.
def _runs_through(spans: Sequence[_Span], start: time, end: time) -> bool:
    reached = start

    for span_start, span_end in spans:
        if span_start > reached:
            break

        reached = max(reached, span_end)

        if reached >= end:
            break

    return reached >= end


def _left_open(occupied: Iterable[_Span], covered: Iterable[_Span]) -> bool:
    shifts = _merged(covered)

    return not all(
        _runs_through(shifts, start, end) for start, end in _merged(occupied)
    )


# One band, one stay: the teacher stays between lessons where their in-person
# hours run on. Mirrors bridgeLessonGaps in room_day_plan.dart.
def _bridged(spans: Iterable[_Span], presence: Iterable[_Span]) -> list[_Span]:
    open_hours = _merged(presence)
    joined: list[_Span] = []

    for start, end in _merged(spans):
        if joined and _runs_through(open_hours, joined[-1][1], start):
            joined[-1] = (joined[-1][0], end)

            continue

        joined.append((start, end))

    return joined


# A room is uncovered only where a non-supervisor teaches and no supervisor is
# there; attività never count. Mirrors isRoomPlanSettled in
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

    occupied: dict[int, list[_Span]] = defaultdict(list)
    stays: dict[tuple[int, str, time, str], list[_Span]] = defaultdict(list)
    presence: dict[str, list[_Span]] = defaultdict(list)

    for lesson in lessons:
        if lesson.teacher_mode != "presence":
            continue

        teacher = teacher_of(lesson)
        stretch = stretch_at(
            stretches.get(teacher, []),
            lesson.start_time,
            lesson.end_time,
        )
        availability = lesson.availability

        presence[teacher].append((availability.start_time, availability.end_time))

        if stretch is None:
            continue

        hours = (lesson.start_time, lesson.end_time)

        occupied[stretch.room_id].append(hours)

        if (stretch.room_id, teacher) in watching:
            key = (stretch.room_id, teacher, stretch.start_time, str(lesson.band))
            stays[key].append(hours)

    covered: dict[int, list[_Span]] = defaultdict(list)

    for (room_id, teacher, _, _), hours in stays.items():
        covered[room_id].extend(_bridged(hours, presence[teacher]))

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
