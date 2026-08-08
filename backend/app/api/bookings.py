from collections.abc import Sequence
from datetime import date
from itertools import chain

from fastapi import APIRouter, Depends

from app.api.booking_presentation import booking_summary, teacher_tax_codes
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.models.booking import Booking
from app.models.person import Person
from app.repositories.booking_repository import BookingRepository
from app.repositories.person_repository import PersonRepository
from app.repositories.presence_repository import PresenceRepository
from app.schemas.booking import (
    BookingCreate,
    BookingResponse,
    BookingUpdate,
    PresenceSummary,
)
from app.schemas.person import PersonOption
from app.services.booking_service import BookingService

router = APIRouter(
    prefix="/bookings",
    tags=["bookings"],
    dependencies=[Depends(require_role("PARENT", "STUDENT", "ADMIN"))],
)


def _to_response(booking: Booking, people: dict[str, Person]) -> BookingResponse:
    presence = booking.presence

    return BookingResponse(
        **booking_summary(booking, people).model_dump(),
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
    tax_codes = chain(
        (booking.presence.student_tax_code for booking in bookings),
        teacher_tax_codes(bookings),
    )
    people = await PersonRepository(db).get_options(tax_codes)

    return [_to_response(booking, people) for booking in bookings]


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


@router.put("/{booking_id}", response_model=BookingResponse)
async def update_booking(
    booking_id: int,
    payload: BookingUpdate,
    identity: CurrentIdentity,
    db: DbSession,
) -> BookingResponse:
    booking = await _services(db).update(identity, booking_id, payload)

    return (await _to_responses(db, [booking]))[0]


@router.delete("/{booking_id}")
async def delete_booking(
    booking_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _services(db).delete(identity, booking_id)

    return {"detail": "Prenotazione eliminata"}
