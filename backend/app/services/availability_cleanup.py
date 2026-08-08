from __future__ import annotations

from collections.abc import Iterable
from datetime import date

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.availability import Availability
from app.models.opening_day import OpeningDay
from app.models.presence import Presence


# Deletes what the teachers offered and what the pupils asked for on the given
# dates, where the association no longer opens in that mode, and returns how many
# rows were removed with both kinds counted together.
#
# Closing a day is not a change of hours, it is the end of the question those
# rows were answering. Left in place they would also be unreachable — the page
# shows a closed day as closed and offers nothing to open — so they would sit in
# the table forever, counted by every statistic and shown by nothing.
#
# Deliberately not run inside its own transaction: it is part of the change that
# closed the day, and either both land or neither does.
async def purge_availabilities_for_closed_days(
    session: AsyncSession,
    dates: Iterable[date],
    mode: str,
) -> int:
    unique_dates = sorted(set(dates))

    if not unique_dates:
        return 0

    open_dates = set(
        (
            await session.execute(
                select(OpeningDay.date)
                .where(
                    OpeningDay.date.in_(unique_dates),
                    OpeningDay.mode == mode,
                    OpeningDay.start_time.is_not(None),
                )
                .distinct()
            )
        )
        .scalars()
        .all()
    )

    closed_dates = [value for value in unique_dates if value not in open_dates]

    if not closed_dates:
        return 0

    availabilities = await session.execute(
        delete(Availability).where(
            Availability.date.in_(closed_dates),
            Availability.mode == mode,
        )
    )

    # Loaded and deleted one by one rather than in a single statement: the
    # bookings under a presence go with it through the relationship's cascade,
    # which a bulk DELETE would step around, leaving them behind with nothing to
    # hang from.
    presences = (
        (
            await session.execute(
                select(Presence).where(
                    Presence.date.in_(closed_dates),
                    Presence.mode == mode,
                )
            )
        )
        .scalars()
        .all()
    )

    for presence in presences:
        await session.delete(presence)

    await session.flush()

    return (availabilities.rowcount or 0) + len(presences)
