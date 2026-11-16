from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def _lock(db: AsyncSession, key: str) -> None:
    await db.execute(select(func.pg_advisory_xact_lock(func.hashtext(key))))


# Taken before anything is read, so two writes on one person never both pass the
# same checks: what is read after it is current.
async def lock_account(db: AsyncSession, tax_code: str) -> None:
    await _lock(db, f"accounting:{tax_code}")


# One daily summary's band: its teachers' or its pupils' side.
async def lock_band(db: AsyncSession, side: str, day: date, band: str) -> None:
    await _lock(db, f"accounting-band:{side}:{day.isoformat()}:{band}")

