from collections.abc import Mapping, Sequence
from datetime import date

from fastapi import APIRouter, BackgroundTasks, Depends

from app.api.booking_presentation import (
    AvoidedTeachers,
    booking_people,
    booking_summary,
)
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.models.booking import Booking
from app.models.person import Person
from app.repositories.booking_repository import BookingRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.booking import (
    BookingCreate,
    BookingResponse,
    BookingUpdate,
    PresenceSummary,
)
from app.schemas.person import PersonOption
from app.services import push
from app.services.booking_notifications import Lesson, pupil_lessons, tell_changes
from app.services.booking_service import BookingService
from app.services.push import PushBatch

router = APIRouter(
    prefix="/bookings",
    tags=["bookings"],
    dependencies=[Depends(require_role("PARENT", "STUDENT", "ADMIN"))],
)


def _to_response(
    booking: Booking,
    people: dict[str, Person],
    avoided: AvoidedTeachers,
) -> BookingResponse:
    presence = booking.presence

    return BookingResponse(
        **booking_summary(
            booking,
            people,
            avoided.get(presence.student_tax_code, []),
        ).model_dump(),
        presence_id=booking.presence_id,
        presence=PresenceSummary(
            id=presence.id,
            date=presence.date,
            start_time=presence.start_time,
            end_time=presence.end_time,
            student=PersonOption.model_validate(people[presence.student_tax_code]),
        ),
    )


async def _to_responses(
    db: DbSession,
    bookings: Sequence[Booking],
) -> list[BookingResponse]:
    people, avoided = await booking_people(
        db,
        bookings,
        students=(booking.presence.student_tax_code for booking in bookings),
    )

    return [_to_response(booking, people, avoided) for booking in bookings]


def _services(db: DbSession) -> BookingService:
    return BookingService(BookingRepository(db), PresenceRepository(db))


@router.get("/", response_model=list[BookingResponse])
async def list_bookings(
    identity: CurrentIdentity,
    db: DbSession,
    presence_id: int | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[BookingResponse]:
    bookings = await _services(db).list_for(
        identity,
        presence_id=presence_id,
        date_from=date_from,
        date_to=date_to,
    )

    return await _to_responses(db, bookings)


@router.post("/", response_model=BookingResponse)
async def create_booking(
    payload: BookingCreate,
    identity: CurrentIdentity,
    db: DbSession,
) -> BookingResponse:
    booking = await _services(db).create(identity, payload)

    return (await _to_responses(db, [booking]))[0]


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> BookingResponse:
    booking = await _services(db).get_owned_or_404(identity, booking_id)

    return (await _to_responses(db, [booking]))[0]


# Changed or cancelled by whoever it was: the pupil and the parents hear of it.
async def _tell(
    db: DbSession,
    identity: CurrentIdentity,
    pupil: str | None,
    before: Mapping[int, Lesson],
    after: Mapping[int, Lesson],
) -> PushBatch:
    if pupil is None:
        return PushBatch(web=[], android=[])

    told = await tell_changes(
        db,
        booker_tax_code=identity.tax_code,
        pupil_tax_code=pupil,
        before=before,
        after=after,
    )
    await db.commit()

    return told


@router.put("/{booking_id}", response_model=BookingResponse)
async def update_booking(
    booking_id: int,
    payload: BookingUpdate,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> BookingResponse:
    pupil, before = await pupil_lessons(db, booking_id=booking_id)
    booking = await _services(db).update(identity, booking_id, payload)
    response = (await _to_responses(db, [booking]))[0]
    _, after = await pupil_lessons(db, booking_id=booking_id)
    background.add_task(push.deliver, await _tell(db, identity, pupil, before, after))

    return response


@router.delete("/{booking_id}")
async def delete_booking(
    booking_id: int,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> dict[str, str]:
    pupil, before = await pupil_lessons(db, booking_id=booking_id)
    await _services(db).delete(identity, booking_id)
    background.add_task(push.deliver, await _tell(db, identity, pupil, before, {}))

    return {"detail": "Prenotazione eliminata"}
