from collections.abc import Sequence
from datetime import date, time
from typing import Any, Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.booking import Booking
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_teacher_exclusion import CalendarTeacherExclusion
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.room_supervision import RoomSupervision
from app.models.teacher import Teacher
from app.models.teacher_room_assignment import TeacherRoomAssignment

# Full row snapshot (not a hash) so closing a bozza without publishing can
# recreate the band; rows carry no ids because they are recreated, not resurrected.

_LESSONS: Final[str] = "lessons"
_ASSIGNMENTS: Final[str] = "assignments"
_SUPERVISIONS: Final[str] = "supervisions"
_ACTIVITIES: Final[str] = "activities"
_EXCLUSIONS: Final[str] = "exclusions"


def _lesson_row(lesson: Lesson) -> dict[str, Any]:
    return {
        "availability_id": lesson.availability_id,
        "teacher_tax_code": lesson.availability.teacher_tax_code,
        "teacher_mode": lesson.teacher_mode,
        "mode": lesson.mode,
        "start_time": lesson.start_time.isoformat(),
        "end_time": lesson.end_time.isoformat(),
        # Sorted so two reads of the same data serialize identically.
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


def _activity_row(activity: CalendarActivity) -> dict[str, Any]:
    availability = activity.availability

    return {
        "name": activity.name,
        "description": activity.description,
        "availability_id": activity.availability_id,
        "teacher_tax_code": (
            availability.teacher_tax_code if availability is not None else None
        ),
        "teacher_mode": activity.teacher_mode,
        "start_time": (
            activity.start_time.isoformat() if activity.start_time is not None else None
        ),
        "end_time": (
            activity.end_time.isoformat() if activity.end_time is not None else None
        ),
    }


def _ordered(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(rows, key=lambda row: sorted(row.items(), key=lambda p: p[0]))


# Sorts via str() because activity fields may be None, which _ordered cannot compare.
def _ordered_activities(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        rows,
        key=lambda row: [(key, str(row[key])) for key in sorted(row)],
    )


# Room assignments span the whole day, not just the band.
def snapshot_of(
    lessons: Sequence[Lesson],
    assignments: Sequence[TeacherRoomAssignment],
    supervisions: Sequence[RoomSupervision],
    activities: Sequence[CalendarActivity] = (),
    exclusions: Sequence[CalendarTeacherExclusion] = (),
) -> dict[str, Any]:
    return {
        _LESSONS: _ordered([_lesson_row(lesson) for lesson in lessons]),
        _ASSIGNMENTS: _ordered([_assignment_row(row) for row in assignments]),
        _SUPERVISIONS: _ordered([_supervision_row(row) for row in supervisions]),
        _ACTIVITIES: _ordered_activities(
            [_activity_row(activity) for activity in activities],
        ),
        _EXCLUSIONS: sorted(row.teacher_tax_code for row in exclusions),
    }


# Exclusions were never published, so they don't count toward "changed".
def _as_published(snapshot: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in snapshot.items() if key != _EXCLUSIONS}


def differs(before: dict[str, Any], after: dict[str, Any]) -> bool:
    return _as_published(before) != _as_published(after)


def _time(value: str) -> time:
    return time.fromisoformat(value)


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


# Restores the band; returns how many snapshot lessons could not be restored.
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
    await _restore_activities(session, day, band, snapshot)
    await _restore_exclusions(session, day, band, snapshot)

    return len(stored) - len(surviving)


async def _restore_exclusions(
    session: AsyncSession,
    day: date,
    band: str,
    snapshot: dict[str, Any],
) -> None:
    current = (
        await session.scalars(
            select(CalendarTeacherExclusion).where(
                CalendarTeacherExclusion.date == day,
                CalendarTeacherExclusion.band == band,
            ),
        )
    ).all()

    for exclusion in current:
        await session.delete(exclusion)

    await session.flush()

    wanted = set(snapshot.get(_EXCLUSIONS, []))

    if not wanted:
        return

    teaching = set(
        (
            await session.scalars(
                select(Teacher.tax_code).where(Teacher.tax_code.in_(wanted)),
            )
        ).all(),
    )

    for tax_code in sorted(wanted & teaching):
        session.add(
            CalendarTeacherExclusion(
                date=day,
                band=band,
                teacher_tax_code=tax_code,
            ),
        )

    await session.flush()


# Matches on (id, date, mode): an availability moved to another day no longer counts.
async def _still_offered(
    session: AsyncSession,
    rows: list[dict[str, Any]],
) -> set[tuple[int, date, str]]:
    wanted = {row["availability_id"] for row in rows if row["availability_id"]}

    if not wanted:
        return set()

    found = (
        await session.execute(
            select(
                Availability.id,
                Availability.date,
                Availability.mode,
            ).where(Availability.id.in_(wanted)),
        )
    ).all()

    return {(identifier, day, mode) for identifier, day, mode in found}


# Activities whose hours have gone come back unassigned, never lost.
async def _restore_activities(
    session: AsyncSession,
    day: date,
    band: str,
    snapshot: dict[str, Any],
) -> None:
    rows = snapshot.get(_ACTIVITIES, [])

    current = (
        await session.scalars(
            select(CalendarActivity).where(
                CalendarActivity.date == day,
                CalendarActivity.band == band,
            ),
        )
    ).all()

    for activity in current:
        await session.delete(activity)

    await session.flush()

    offered = await _still_offered(session, rows)

    for row in rows:
        kept = (row["availability_id"], day, row["teacher_mode"]) in offered

        session.add(
            CalendarActivity(
                date=day,
                band=band,
                name=row["name"],
                description=row["description"],
                availability_id=row["availability_id"] if kept else None,
                teacher_mode=row["teacher_mode"] if kept else None,
                start_time=_time(row["start_time"]) if kept else None,
                end_time=_time(row["end_time"]) if kept else None,
            ),
        )

    await session.flush()


# Only this band's teachers: assignments are day-wide and shared with other bands.
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

    # Supervisions are deleted by cascade with the assignment.
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
