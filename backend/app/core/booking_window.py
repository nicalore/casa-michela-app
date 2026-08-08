from datetime import date, datetime, time, timedelta
from typing import Final
from zoneinfo import ZoneInfo

_ROME_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

# Monday=0 .. Sunday=6, per date.weekday().
_UNLOCK_WEEKDAY: Final[int] = 4
_UNLOCK_HOUR: Final[int] = 20
_CURRENT_WEEK_LAST_OFFSET: Final[int] = 6
_NEXT_WEEK_LAST_OFFSET: Final[int] = 13

_OUT_OF_WINDOW_ERROR: Final[str] = (
    "La data selezionata non rientra nella finestra di prenotazione "
    "attualmente sbloccata."
)


# Rolling weekly unlock: every Friday at 20:00 the whole following week opens
# up, on top of whatever is left of the already unlocked current one.
def compute_available_window(now: datetime) -> tuple[date, date]:
    today = now.date()
    current_week_monday = today - timedelta(days=today.weekday())
    unlock_moment = datetime.combine(
        current_week_monday + timedelta(days=_UNLOCK_WEEKDAY),
        time(_UNLOCK_HOUR),
        tzinfo=now.tzinfo,
    )
    last_unlocked_offset = (
        _NEXT_WEEK_LAST_OFFSET
        if now >= unlock_moment
        else _CURRENT_WEEK_LAST_OFFSET
    )

    return today, current_week_monday + timedelta(days=last_unlocked_offset)


def today_in_rome() -> date:
    return datetime.now(_ROME_TIMEZONE).date()


# The ValueError is mapped to HTTP 400 by the app-wide handler.
def assert_within_booking_window(target_date: date) -> None:
    today, max_unlocked = compute_available_window(datetime.now(_ROME_TIMEZONE))

    if target_date < today or target_date > max_unlocked:
        raise ValueError(_OUT_OF_WINDOW_ERROR)
