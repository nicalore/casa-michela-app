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


# Hours must fall inside a single opening band of that day and mode. The
# client enforces this too, but the rule belongs to the domain.
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
