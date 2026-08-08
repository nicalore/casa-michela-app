from fastapi import APIRouter, Depends, status

from app.api.dependencies import DbSession
from app.api.presences import to_responses
from app.api.rbac import CurrentIdentity, require_role
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.lesson_request import LessonRequestCreate
from app.schemas.presence import PresenceResponse
from app.services.booking_service import BookingService
from app.services.lesson_request_service import LessonRequestService
from app.services.presence_service import PresenceService

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


@router.post(
    "/",
    response_model=list[PresenceResponse],
    status_code=status.HTTP_201_CREATED,
)
# Books a day's hours and the lessons to hold in them, in one transaction, and
# answers with the stretches created and the lessons hanging off each, which is
# how the client groups them anyway. /presences and /bookings stay for editing
# one row at a time.
async def create_lesson_request(
    payload: LessonRequestCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> list[PresenceResponse]:
    presences = await _service(db).create(identity, payload)

    return await to_responses(db, presences)
