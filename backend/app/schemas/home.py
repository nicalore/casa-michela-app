from decimal import Decimal

from pydantic import BaseModel

from app.models.student import HomeworkTariffEnum
from app.schemas.person import PersonOption


# A month so far, up to a day and hour: days already lived, hours already held.
class TeacherMonthFigures(BaseModel):
    total_availabilities: int
    weekly_availabilities: float

    worked_minutes: int

    # None without an hourly rate: unpaid collaboration, or a rate nobody entered yet.
    gross_compensation: Decimal | None


class TeacherMonthSummaryResponse(TeacherMonthFigures):
    is_below_monthly_threshold: bool
    is_below_weekly_threshold: bool

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
