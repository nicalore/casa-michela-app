from decimal import Decimal

from pydantic import BaseModel

from app.models.student import HomeworkTariffEnum
from app.schemas.person import PersonOption


# A month so far, up to a day and hour: days already lived, hours already held.
class TeacherMonthFigures(BaseModel):
    total_availabilities: int

    # Averaged over the month's weeks, each read whole from Monday to Sunday.
    weekly_availabilities: float

    worked_minutes: int

    # None without an hourly rate: unpaid collaboration, or a rate nobody entered yet.
    gross_compensation: Decimal | None


class WeekFigures(BaseModel):
    given: int
    required: int


class TeacherMonthSummaryResponse(TeacherMonthFigures):
    is_below_monthly_threshold: bool

    # The average under two, as apps before short_week_count word it.
    is_below_weekly_threshold: bool

    # Weeks already over with fewer days than asked.
    short_week_count: int

    # The week still being filled; None once no opening is left in it.
    current_week: WeekFigures | None

    # The month before, up to the same day and hour, so the two compare like for like.
    last_month: TeacherMonthFigures


class PupilMonthFigures(BaseModel):
    student: PersonOption

    total_presences: int
    weekly_presences: float

    # Days booked from tomorrow to the end of the month.
    booked_presences: int

    lesson_minutes: int

    # How the hours are paid for; a package's balance is not tracked yet.
    homework_tariff: HomeworkTariffEnum | None


class StudentMonthSummaryResponse(BaseModel):
    figures: PupilMonthFigures

    # A pupil somebody answers for reads a narrower card than one who books themselves.
    has_parental_responsibility: bool


class ParentMonthSummaryResponse(BaseModel):
    children: list[PupilMonthFigures]
