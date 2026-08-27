from collections.abc import Iterable, Sequence
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.repositories.calendar_teacher_exclusion_repository import (
    CalendarTeacherExclusionRepository,
)
from app.repositories.lesson_repository import LessonRepository
from app.repositories.room_supervision_repository import RoomSupervisionRepository
from app.repositories.teacher_room_assignment_repository import (
    TeacherRoomAssignmentRepository,
)
from app.services.calendar_snapshot import snapshot_of


async def _settled_pictures(
    session: AsyncSession,
    bands: Iterable[tuple[date, str]],
) -> dict[tuple[date, str], dict]:
    pictures: dict[tuple[date, str], dict] = {}

    for day, band in bands:
        settled = await session.scalar(
            select(CalendarPublication).where(
                CalendarPublication.date == day,
                CalendarPublication.band == band,
                CalendarPublication.draft_snapshot.is_(None),
            ),
        )

        if settled is None:
            continue

        pictures[(day, band)] = snapshot_of(
            await LessonRepository(session).list_for_band(day, band),
            await TeacherRoomAssignmentRepository(session).list_for_day(day),
            await RoomSupervisionRepository(session).list_for_day(day),
            await CalendarActivityRepository(session).list_for_band(day, band),
            await CalendarTeacherExclusionRepository(session).list_for_band(day, band),
        )

    return pictures


async def _open_drafts(
    session: AsyncSession,
    pictures: dict[tuple[date, str], dict],
) -> None:
    for (day, band), picture in pictures.items():
        publication = await session.scalar(
            select(CalendarPublication).where(
                CalendarPublication.date == day,
                CalendarPublication.band == band,
            ),
        )

        if publication is not None and publication.draft_snapshot is None:
            publication.draft_snapshot = picture


# A withdrawn availability takes only the assignment: the activity stays with
# its calendar. Snapshot first — a reopened draft is compared against how the
# band last went out.
async def unassign(
    session: AsyncSession,
    activities: Sequence[CalendarActivity],
) -> int:
    if not activities:
        return 0

    bands = {(activity.date, activity.band) for activity in activities}
    pictures = await _settled_pictures(session, bands)

    for activity in activities:
        activity.availability_id = None
        activity.teacher_mode = None
        activity.start_time = None
        activity.end_time = None

    await session.flush()
    await _open_drafts(session, pictures)

    return len(activities)


async def unschedule(session: AsyncSession, lessons: Sequence[Lesson]) -> int:
    if not lessons:
        return 0

    # Snapshot before the lessons go: the reopened draft is compared against it.
    bands = {(lesson.date, lesson.band) for lesson in lessons}
    pictures = await _settled_pictures(session, bands)

    for lesson in lessons:
        await session.delete(lesson)

    await session.flush()
    await _open_drafts(session, pictures)

    return len(lessons)
