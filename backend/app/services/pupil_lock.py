from collections.abc import Iterable

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking
from app.models.presence import Presence


# Serializes a pupil's booking writes, or concurrent parents both pass the checks.
async def lock_pupil(session: AsyncSession, student_tax_code: str) -> None:
    await session.execute(
        select(
            func.pg_advisory_xact_lock(
                func.hashtext(f"pupil-bookings:{student_tax_code}"),
            ),
        ),
    )


# Tax-code order, so two writes on the same pupils never deadlock.
async def lock_pupils(
    session: AsyncSession,
    student_tax_codes: Iterable[str | None],
) -> None:
    for student_tax_code in sorted({code for code in student_tax_codes if code}):
        await lock_pupil(session, student_tax_code)


async def pupil_of_presence(session: AsyncSession, presence_id: int) -> str | None:
    return await session.scalar(
        select(Presence.student_tax_code).where(Presence.id == presence_id),
    )


async def pupil_of_booking(session: AsyncSession, booking_id: int) -> str | None:
    return await session.scalar(
        select(Presence.student_tax_code)
        .join(Booking, Booking.presence_id == Presence.id)
        .where(Booking.id == booking_id),
    )


# Taken before the row is loaded, so what is read after it is current.
async def lock_pupil_of_presence(session: AsyncSession, presence_id: int) -> None:
    await lock_pupils(session, [await pupil_of_presence(session, presence_id)])


async def lock_pupil_of_booking(session: AsyncSession, booking_id: int) -> None:
    await lock_pupils(session, [await pupil_of_booking(session, booking_id)])
