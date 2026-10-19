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


# Hours must fall inside one opening band of that day and mode; the client checks too.
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

    openings = [
        (opening.start_time, opening.end_time)
        for opening in (await session.execute(stmt)).scalars()
        if opening.start_time is not None and opening.end_time is not None
    ]

    if not openings:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CLOSED_ERROR.format(mode=opening_mode_label(mode)),
        )

    for opens, closes in openings:
        if opens <= start_time and end_time <= closes:
            return

    windows = ", ".join(
        f"{_format_time(opens)}-{_format_time(closes)}" for opens, closes in openings
    )

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=outside_opening_error.format(
            mode=opening_mode_label(mode),
            windows=windows,
        ),
    )
