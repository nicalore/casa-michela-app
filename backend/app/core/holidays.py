from datetime import date, timedelta
from functools import lru_cache
from typing import Final

_FIXED_HOLIDAYS: Final[list[tuple[int, int, str]]] = [
    (1, 1, "Capodanno"),
    (1, 6, "Epifania"),
    (4, 25, "Anniversario della Liberazione"),
    (5, 1, "Festa dei Lavoratori"),
    (6, 2, "Festa della Repubblica"),
    (8, 15, "Ferragosto"),
    (11, 1, "Tutti i Santi"),
    (12, 8, "Immacolata Concezione"),
    (12, 24, "Vigilia di Natale"),
    (12, 25, "Natale"),
    (12, 26, "Santo Stefano"),
    (12, 31, "Ultimo dell'anno"),
]


# Easter Sunday on the Gregorian calendar, via Gauss' algorithm.
def compute_easter(year: int) -> date:
    a = year % 19
    b = year % 4
    c = year % 7
    k = year // 100
    p = (13 + 8 * k) // 25
    q = k // 4
    m = (15 - p + k - q) % 30
    n = (4 + k - q) % 7
    d = (19 * a + m) % 30
    e = (2 * b + 4 * c + 6 * d + n) % 7

    if d == 29 and e == 6:
        return date(year, 4, 19)

    if d == 28 and e == 6 and (11 * m + 11) % 30 < 19:
        return date(year, 4, 18)

    total = 22 + d + e

    if total <= 31:
        return date(year, 3, total)

    return date(year, 4, total - 31)


@lru_cache(maxsize=16)
def _holidays_by_date(year: int) -> dict[date, str]:
    holidays = {
        date(year, month, day): label for month, day, label in _FIXED_HOLIDAYS
    }

    easter = compute_easter(year)
    holidays[easter] = "Pasqua"
    holidays[easter + timedelta(days=1)] = "Lunedì dell'Angelo"

    return holidays


# Defensive copy: the cached map is shared across callers, and the calendar
# generator keeps it inside a structure of its own.
def holidays_for_year(year: int) -> dict[date, str]:
    return dict(_holidays_by_date(year))


# Queries a single day without rebuilding the whole year on every call: this
# runs per row, on responses holding hundreds of them.
def holiday_label(day: date) -> str | None:
    return _holidays_by_date(day.year).get(day)
