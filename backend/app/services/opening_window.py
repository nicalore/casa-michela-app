from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import opening_mode_label
from app.models.opening_day import OpeningDay

_CLOSED_ERROR: Final[str] = "L'associazione non è aperta {mode} in quel giorno."


def _format_time(value: time) -> str:
    return f"{value.hour:02d}:{value.minute:02d}"


# Hours are given against one of the bands the association actually opens that
# day in that mode, and inside a single band rather than spread across two: the
# gap between a morning and an afternoon is time the association is shut, and
# hours running through it would be hours nobody can be taught in.
#
# The client enforces this too — it will not even draw a band the association is
# shut in — but the rule belongs to the domain and not to the screen that
# happens to ask for it.
async def assert_within_opening(
    session: AsyncSession,
    *,
    target_date: date,
    mode: str,
    start_time: time,
    end_time: time,
    outside_opening_error: str,
) -> None:
    stmt = (
        select(OpeningDay)
        .where(
            OpeningDay.date == target_date,
            OpeningDay.mode == mode,
            OpeningDay.start_time.is_not(None),
        )
        .order_by(OpeningDay.start_time)
    )

    openings = (await session.execute(stmt)).scalars().all()

    if not openings:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CLOSED_ERROR.format(mode=opening_mode_label(mode)),
        )

    for opening in openings:
        if opening.start_time <= start_time and end_time <= opening.end_time:
            return

    windows = ", ".join(
        f"{_format_time(opening.start_time)}-{_format_time(opening.end_time)}"
        for opening in openings
    )

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=outside_opening_error.format(
            mode=opening_mode_label(mode),
            windows=windows,
        ),
    )
