from datetime import date


# Italian school years run from September: a day in the spring belongs to the
# year that began the previous autumn.
def school_year_start(day: date) -> int:
    return day.year if day.month >= 9 else day.year - 1
