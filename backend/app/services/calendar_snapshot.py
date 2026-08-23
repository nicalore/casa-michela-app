from collections.abc import Sequence
from datetime import date, time
from typing import Any, Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.room_supervision import RoomSupervision
from app.models.teacher_room_assignment import TeacherRoomAssignment

# What a band looked like when its bozza was opened, kept whole so that closing
# the bozza without publishing can put it back.
#
# An impression would be cheaper and was what this held first, but an impression
# can only answer "is this different" — and leaving a bozza is meant to undo the
# work in it, not merely to decline to send it. So the rows themselves are kept,
# in the plainest shape that can be written back: no ids, since the rows are
# recreated rather than resurrected, and nothing derived, since the database
# computes the band from the hour on its own.
#
# Only the timetable and the rooms, because only they are what went out.

_LESSONS: Final[str] = "lessons"
_ASSIGNMENTS: Final[str] = "assignments"
_SUPERVISIONS: Final[str] = "supervisions"


def _lesson_row(lesson: Lesson) -> dict[str, Any]:
    return {
        "availability_id": lesson.availability_id,
        "teacher_tax_code": lesson.availability.teacher_tax_code,
        "teacher_mode": lesson.teacher_mode,
        "mode": lesson.mode,
        "start_time": lesson.start_time.isoformat(),
        "end_time": lesson.end_time.isoformat(),
        # Sorted, both of them: the order the database hands rows back in is not
        # a fact about the calendar, and two reads of one afternoon have to come
        # out the same string.
        "disciplines": sorted(
            row.association_subject_id for row in lesson.lesson_disciplines
        ),
        "bookings": sorted(link.booking_id for link in lesson.lesson_bookings),
    }


def _assignment_row(assignment: TeacherRoomAssignment) -> dict[str, Any]:
    return {
        "teacher_tax_code": assignment.teacher_tax_code,
        "room_id": assignment.room_id,
    }


def _supervision_row(shift: RoomSupervision) -> dict[str, Any]:
    return {
        "teacher_tax_code": shift.teacher_tax_code,
        "room_id": shift.room_id,
        "start_time": shift.start_time.isoformat(),
        "end_time": shift.end_time.isoformat(),
    }


def _ordered(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(rows, key=lambda row: sorted(row.items(), key=lambda p: p[0]))


# The rooms of the whole day and not of the band: a teacher takes one room for
# the day, so the afternoon's arrangement is visibly the morning's as well.
def snapshot_of(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
    supervisions: Sequence[RoomSupervision],
) -> dict[str, Any]:
    return {
        _LESSONS: _ordered([_lesson_row(lesson) for lesson in lessons]),
        _ASSIGNMENTS: _ordered([_assignment_row(row) for row in assignments]),
        _SUPERVISIONS: _ordered([_supervision_row(row) for row in supervisions]),
    }


# Two snapshots of the same afternoon are the same afternoon. Compared as data
# and not as a hash: the rows are already in one order, and a dict comparison
# says the same thing without a second thing to keep in step.
def differs(before: dict[str, Any], after: dict[str, Any]) -> bool:
    return before != after


def _time(value: str) -> time:
    return time.fromisoformat(value)


# Everything the snapshot rests on that may have gone while the bozza was open:
# an availability withdrawn, a request cancelled. A lesson standing on one of
# those cannot come back — the calendar it was part of is not a state the
# database would accept any more — so it is left out, and the count of what was
# left out goes back to the caller to be said out loud.
async def _surviving(
    session: AsyncSession,
    rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    availabilities = set(
        (
            await session.scalars(
                select(Availability.id).where(
                    Availability.id.in_({row["availability_id"] for row in rows}),
                ),
            )
        ).all(),
    )

    wanted = {booking for row in rows for booking in row["bookings"]}
    bookings = set(
        (
            await session.scalars(
                select(Booking.id).where(Booking.id.in_(wanted)),
            )
        ).all(),
    )

    return [
        row
        for row in rows
        if row["availability_id"] in availabilities
        and all(booking in bookings for booking in row["bookings"])
    ]


# Puts the band back as the snapshot has it. Answers how many of its hours could
# not be put back, which is not a failure: a request withdrawn while the bozza
# was open takes its hour with it either way.
async def restore(
    session: AsyncSession,
    day: date,
    band: str,
    snapshot: dict[str, Any],
) -> int:
    stored = snapshot.get(_LESSONS, [])
    surviving = await _surviving(session, stored)

    current = (
        await session.scalars(
            select(Lesson).where(Lesson.date == day, Lesson.band == band),
        )
    ).all()

    for lesson in current:
        await session.delete(lesson)

    await session.flush()

    for row in surviving:
        lesson = Lesson(
            availability_id=row["availability_id"],
            date=day,
            teacher_mode=row["teacher_mode"],
            mode=row["mode"],
            start_time=_time(row["start_time"]),
            end_time=_time(row["end_time"]),
        )

        lesson.lesson_disciplines = [
            LessonDiscipline(association_subject_id=subject)
            for subject in row["disciplines"]
        ]
        lesson.lesson_bookings = [
            LessonBooking(booking_id=booking) for booking in row["bookings"]
        ]

        session.add(lesson)

    await session.flush()
    await _restore_rooms(session, day, snapshot, surviving)

    return len(stored) - len(surviving)


# Only the teachers this band's hours are about.
#
# A room is one row per teacher for the whole day, so it is shared with the
# other parts of that day: putting back every room of the day would undo the
# arrangement somebody made for the evening while the afternoon was in bozza.
# Whoever teaches in both is genuinely one row and there is no answer that is
# right for both, so the band being put back wins.
async def _restore_rooms(
    session: AsyncSession,
    day: date,
    snapshot: dict[str, Any],
    lessons: list[dict[str, Any]],
) -> None:
    teachers = {row["teacher_tax_code"] for row in lessons}

    if not teachers:
        return

    current = (
        await session.scalars(
            select(TeacherRoomAssignment).where(
                TeacherRoomAssignment.date == day,
                TeacherRoomAssignment.teacher_tax_code.in_(teachers),
            ),
        )
    ).all()

    # The shifts hang off the assignment and go with it, by cascade.
    for assignment in current:
        await session.delete(assignment)

    await session.flush()

    rooms = {
        row["teacher_tax_code"]: row["room_id"]
        for row in snapshot.get(_ASSIGNMENTS, [])
        if row["teacher_tax_code"] in teachers
    }

    for teacher, room_id in rooms.items():
        session.add(
            TeacherRoomAssignment(date=day, teacher_tax_code=teacher, room_id=room_id),
        )

    await session.flush()

    for row in snapshot.get(_SUPERVISIONS, []):
        if rooms.get(row["teacher_tax_code"]) != row["room_id"]:
            continue

        session.add(
            RoomSupervision(
                date=day,
                teacher_tax_code=row["teacher_tax_code"],
                room_id=row["room_id"],
                start_time=_time(row["start_time"]),
                end_time=_time(row["end_time"]),
            ),
        )

    await session.flush()
