from collections.abc import Collection
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import ColumnElement, and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.rbac import IdentityContext
from app.core.booking_window import now_in_rome
from app.models.availability import Availability
from app.models.booking import mark_swept
from app.models.lesson import Lesson
from app.models.member import Member
from app.models.presence import Presence
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.repositories.calendar_activity_repository import (
    CalendarActivityRepository,
)
from app.services.availability_cleanup import lessons_standing_on
from app.services.pupil_lock import lock_pupil
from app.services.role_service import RoleService
from app.services.schedule_cascade import unassign, unschedule

_NOT_COLLABORATING_ERROR: Final[str] = "Questa persona non è un collaboratore attivo"


# Mirrors activeCollaborators in frontend/lib/features/people/models/person_item.dart.
def is_collaborating(member: Member | None) -> bool:
    return (
        member is not None
        and member.collaborating_active
        and RoleService.is_enrolled(member)
    )


# Binds only admins acting for others; people and parents book regardless.
async def assert_admin_may_name(
    session: AsyncSession,
    identity: IdentityContext,
    tax_code: str,
) -> None:
    if (
        not identity.is_admin
        or tax_code == identity.tax_code
        or tax_code in identity.child_tax_codes
    ):
        return

    if not is_collaborating(await _member(session, tax_code)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NOT_COLLABORATING_ERROR,
        )


async def _member(session: AsyncSession, tax_code: str) -> Member | None:
    return await session.scalar(
        select(Member)
        .options(selectinload(Member.memberships))
        .where(Member.tax_code == tax_code),
    )


# Booking or giving hours resumes collaboration, enrolled only; the caller commits.
async def resume_collaboration(session: AsyncSession, tax_code: str) -> None:
    member = await _member(session, tax_code)

    if (
        member is None
        or member.collaborating_active
        or not RoleService.is_enrolled(member)
    ):
        return

    member.collaborating_active = True
    await session.flush()


# Not begun yet: today's later hours count as ahead.
def _ahead(
    model: type[Availability] | type[Presence],
    today: date,
    clock: time,
) -> ColumnElement[bool]:
    return or_(
        model.date > today,
        and_(model.date == today, model.start_time > clock),
    )


# Rooms on days left without in-person lessons go; supervisions cascade.
async def _drop_idle_rooms(
    session: AsyncSession,
    teacher_tax_code: str,
    days: Collection[date],
) -> None:
    if not days:
        return

    still_teaching = set(
        await session.scalars(
            select(Lesson.date)
            .join(Availability, Availability.id == Lesson.availability_id)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                Lesson.date.in_(days),
                Lesson.teacher_mode == "presence",
            ),
        ),
    )

    for assignment in await session.scalars(
        select(TeacherRoomAssignment).where(
            TeacherRoomAssignment.teacher_tax_code == teacher_tax_code,
            TeacherRoomAssignment.date.in_(days),
        ),
    ):
        if assignment.date not in still_teaching:
            await session.delete(assignment)

    await session.flush()


# Drops presences and availabilities ahead, with their lessons; the caller commits.
async def drop_hours_ahead(session: AsyncSession, tax_code: str) -> None:
    await lock_pupil(session, tax_code)

    now = now_in_rome()
    today, clock = now.date(), now.time()

    availabilities = (
        await session.scalars(
            select(Availability).where(
                Availability.teacher_tax_code == tax_code,
                _ahead(Availability, today, clock),
            ),
        )
    ).all()
    presences = (
        await session.scalars(
            select(Presence).where(
                Presence.student_tax_code == tax_code,
                _ahead(Presence, today, clock),
            ),
        )
    ).all()

    if not availabilities and not presences:
        return

    await unschedule(
        session,
        await lessons_standing_on(
            session,
            {availability.id for availability in availabilities},
            {presence.id for presence in presences},
        ),
    )

    activities = CalendarActivityRepository(session)

    for availability in availabilities:
        await unassign(session, await activities.find_for_availability(availability.id))
        await session.delete(availability)

    # Bookings cascade with their presence.
    for presence in presences:
        mark_swept(session.sync_session, presence)
        await session.delete(presence)

    await session.flush()

    await _drop_idle_rooms(
        session,
        tax_code,
        {availability.date for availability in availabilities},
    )
