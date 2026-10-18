from collections.abc import Mapping, Sequence
from datetime import date

from fastapi import APIRouter, BackgroundTasks, Depends, status

from app.api.dependencies import DbSession
from app.api.presences import to_responses
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.models.presence import Presence
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.lesson_request import (
    LessonRequestCreate,
    LessonRequestReplace,
    LessonRequestReplaceDays,
)
from app.schemas.presence import PresenceResponse
from app.services import push
from app.services.booking_notifications import Lesson, lessons_of, tell_changes
from app.services.booking_service import BookingService
from app.services.daily_reminders import presence_booked
from app.services.lesson_request_service import LessonRequestService
from app.services.presence_service import PresenceService
from app.services.push import joined

router = APIRouter(
    prefix="/lesson-requests",
    tags=["lesson-requests"],
    dependencies=[Depends(require_role("PARENT", "STUDENT", "ADMIN"))],
)


def _service(db: DbSession) -> LessonRequestService:
    presence_repository = PresenceRepository(db)

    return LessonRequestService(
        db,
        PresenceService(presence_repository),
        BookingService(BookingRepository(db), presence_repository),
    )


# Booked: those days' evening reminders go, and the pupil and the parents hear of
# the lessons someone else added, changed or cancelled, against those read before.
async def _settle(
    db: DbSession,
    background: BackgroundTasks,
    identity: IdentityContext,
    pupil: str,
    days: Sequence[date],
    before: Mapping[int, Lesson],
    presences: Sequence[Presence],
) -> None:
    batches = [
        await presence_booked(db, pupil, day)
        for day in sorted({presence.date for presence in presences})
    ]
    batches.append(
        await tell_changes(
            db,
            booker_tax_code=identity.tax_code,
            pupil_tax_code=pupil,
            before=before,
            after=await lessons_of(db, pupil, days),
        )
    )
    await db.commit()
    background.add_task(push.deliver, joined(batches))


@router.post(
    "/",
    response_model=list[PresenceResponse],
    status_code=status.HTTP_201_CREATED,
)
# One transaction for a day's hours plus their lessons; /presences and
# /bookings stay for single-row edits.
async def create_lesson_request(
    payload: LessonRequestCreate,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> list[PresenceResponse]:
    pupil = payload.student_tax_code
    before = await lessons_of(db, pupil, [payload.date])
    presences = await _service(db).create(identity, payload)
    await _settle(db, background, identity, pupil, [payload.date], before, presences)

    return await to_responses(db, identity, presences)


@router.put("/", response_model=list[PresenceResponse])
# The wizard's edits of a day in one transaction, checked on the result.
async def replace_lesson_request(
    payload: LessonRequestReplace,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> list[PresenceResponse]:
    pupil = payload.student_tax_code
    before = await lessons_of(db, pupil, [payload.date])
    presences = await _service(db).replace(identity, payload)
    await _settle(db, background, identity, pupil, [payload.date], before, presences)

    return await to_responses(db, identity, presences)


@router.put("/days", response_model=list[PresenceResponse])
# A move between days or modes in one transaction, checked on the result.
async def replace_lesson_request_days(
    payload: LessonRequestReplaceDays,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> list[PresenceResponse]:
    pupil = payload.student_tax_code
    per_day = payload.per_day()
    days = [day.date for day in per_day]
    before = await lessons_of(db, pupil, days)
    presences = await _service(db).replace_days(identity, per_day)
    await _settle(db, background, identity, pupil, days, before, presences)

    return await to_responses(db, identity, presences)
