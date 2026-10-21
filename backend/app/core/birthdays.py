import calendar
from datetime import date


# Feb 29 falls on the 28th in common years. Mirrors the frontend's birthday.dart.
def birthday_in(year: int, birth: date) -> date:
    leap_day = (birth.month, birth.day) == (2, 29)
    day = 28 if leap_day and not calendar.isleap(year) else birth.day

    return date(year, birth.month, day)


def age_on(birth: date, day: date) -> int:
    return day.year - birth.year - (day < birthday_in(day.year, birth))


def is_birthday(birth: date, day: date) -> bool:
    return birthday_in(day.year, birth) == day
