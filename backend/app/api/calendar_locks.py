from collections.abc import Sequence
from datetime import date, timedelta

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.time_band import TimeBandEnum
from app.models.calendar_band_lock import LOCK_TTL_SECONDS, CalendarBandLock
from app.models.person import Person
from app.repositories.calendar_band_lock_repository import (
    CalendarBandLockRepository,
)
from app.repositories.person_repository import PersonRepository
from app.schemas.calendar_lock import CalendarLockResponse, CalendarLockState
from app.schemas.person import PersonOption

router = APIRouter(
    prefix="/calendar-locks",
    tags=["calendar-locks"],
    dependencies=[Depends(require_role("ADMIN"))],
)


def _to_response(lock: CalendarBandLock, people: dict[str, Person]) -> CalendarLockResponse:
    holder = people.get(lock.holder_tax_code)

    return CalendarLockResponse(
        date=lock.date,
        band=TimeBandEnum(lock.band),
        holder_tax_code=lock.holder_tax_code,
        holder=PersonOption.model_validate(holder) if holder is not None else None,
        acquired_at=lock.acquired_at,
        expires_at=lock.heartbeat_at + timedelta(seconds=LOCK_TTL_SECONDS),
    )


async def _to_responses(
    db: DbSession,
    locks: Sequence[CalendarBandLock],
) -> list[CalendarLockResponse]:
    if not locks:
        return []

    people = await PersonRepository(db).get_options(
        lock.holder_tax_code for lock in locks
    )

    return [_to_response(lock, people) for lock in locks]


def _repository(db: DbSession) -> CalendarBandLockRepository:
    return CalendarBandLockRepository(db)


@router.get("/", response_model=list[CalendarLockResponse])
async def list_locks(
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[CalendarLockResponse]:
    return await _to_responses(
        db,
        await _repository(db).live(date_from=date_from, date_to=date_to),
    )


# There is no separate acquire endpoint: the heartbeat itself takes the band.
# Responds with the current lock state either way, so a client learns here that
# it lost the band.
@router.post("/{lock_date}/{band}/heartbeat", response_model=CalendarLockState)
async def heartbeat(
    lock_date: date,
    band: TimeBandEnum,
    identity: CurrentIdentity,
    db: DbSession,
) -> CalendarLockState:
    locks = _repository(db)
    beaten = await locks.claim(lock_date, str(band), identity.tax_code)

    if beaten is not None:
        await db.commit()

        return CalendarLockState(
            lock=(await _to_responses(db, [beaten]))[0],
            mine=True,
        )

    held = await locks.holder(lock_date, str(band))

    return CalendarLockState(
        lock=(await _to_responses(db, [held]))[0] if held is not None else None,
        mine=False,
    )


# Best effort: the TTL covers browsers that closed without calling this.
@router.delete("/{lock_date}/{band}")
async def release_lock(
    lock_date: date,
    band: TimeBandEnum,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    await _repository(db).release(lock_date, str(band), identity.tax_code)
    await db.commit()

    return {"detail": "Calendario lasciato"}
