from datetime import date


# Italian school years run from September: a spring day belongs to the previous autumn.
def school_year_start(day: date) -> int:
    return day.year if day.month >= 9 else day.year - 1
