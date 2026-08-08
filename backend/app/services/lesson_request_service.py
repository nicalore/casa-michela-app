from collections.abc import Iterator
from typing import Final

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.core.time_step import minutes_between
from app.models.presence import Presence
from app.schemas.lesson_request import LessonRequestCreate, LessonRequestSubject
from app.schemas.presence import PresenceCreate
from app.services.booking_service import BookingService
from app.services.presence_service import PresenceService

_CREATE_ERROR: Final[str] = "Errore durante la creazione della richiesta."


# Hangs each lesson off one of the stretches the pupil gave. A booking has no
# hours of its own, only a length, and the rule the domain enforces is a total
# for the day: so this is first fit in clock order, the earliest stretch with
# room left. When no single stretch is long enough it falls back on the roomiest
# one rather than refusing — that is a timetabling problem, not an invalid
# request, and rejecting it here would be stricter than the invariant.
def assign_presences(
    presences: list[Presence],
    subjects: list[LessonRequestSubject],
) -> Iterator[tuple[Presence, LessonRequestSubject]]:
    ordered = sorted(presences, key=lambda presence: presence.start_time)
    remaining = {
        id(presence): minutes_between(presence.start_time, presence.end_time)
        for presence in ordered
    }

    for subject in subjects:
        target = next(
            (
                presence
                for presence in ordered
                if remaining[id(presence)] >= subject.duration
            ),
            None,
        )

        if target is None:
            target = max(ordered, key=lambda presence: remaining[id(presence)])

        remaining[id(target)] -= subject.duration

        yield target, subject


# One booking session written in one transaction: the hours, then the lessons.
# Every rule it applies belongs to PresenceService and BookingService; what it
# owns is the transaction. The two services hand back rows that are staged but
# not committed, and the single commit at the end makes the request
# all-or-nothing.
class LessonRequestService:
    def __init__(
        self,
        session: AsyncSession,
        presence_service: PresenceService,
        booking_service: BookingService,
    ) -> None:
        self.session = session
        self.presence_service = presence_service
        self.booking_service = booking_service

    async def create(
        self,
        identity: IdentityContext,
        payload: LessonRequestCreate,
    ) -> list[Presence]:
        presences: list[Presence] = []

        async with integrity_guard(self.session, _CREATE_ERROR):
            try:
                # Mode by mode, because each has its own bands and its own
                # hours: assigning an online lesson to a band in the building
                # would put it in a time it was never asked for.
                for block in payload.modes:
                    block_presences = [
                        await self.presence_service.prepare_create(
                            identity,
                            PresenceCreate(
                                date=payload.date,
                                mode=block.mode,
                                start_time=slot.start_time,
                                end_time=slot.end_time,
                                student_tax_code=payload.student_tax_code,
                                booker_tax_code=payload.booker_tax_code,
                            ),
                        )
                        for slot in block.slots
                    ]

                    for presence, subject in assign_presences(
                        block_presences,
                        block.subjects,
                    ):
                        # Passing presence= also fills presence.bookings in
                        # memory via back_populates, so the response is built
                        # with no further IO.
                        self.session.add(
                            await self.booking_service.build_for_presence(
                                presence,
                                subject,
                            )
                        )

                    presences.extend(block_presences)

                await self.session.flush()
                await self.session.commit()

            except HTTPException:
                # Nothing has been committed, so this leaves no half-written
                # request behind; the rollback is explicit rather than left to
                # the session closing, so the transaction is not held open
                # meanwhile.
                await self.session.rollback()
                raise

        return presences
