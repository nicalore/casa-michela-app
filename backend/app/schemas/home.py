from decimal import Decimal

from pydantic import BaseModel

from app.models.student import HomeworkTariffEnum
from app.schemas.person import PersonOption


# The month so far, up to now: days already lived, hours already held.
class TeacherMonthSummaryResponse(BaseModel):
    total_availabilities: int
    weekly_availabilities: float

    is_below_monthly_threshold: bool
    is_below_weekly_threshold: bool

    worked_minutes: int

    # None when the teacher has no hourly rate: an unpaid collaboration, or
    # a rate nobody entered yet.
    gross_compensation: Decimal | None


class PupilMonthFigures(BaseModel):
    student: PersonOption

    total_presences: int
    weekly_presences: float

    lesson_minutes: int

    # How the hours are paid for; a package's balance is not tracked yet.
    homework_tariff: HomeworkTariffEnum | None


class StudentMonthSummaryResponse(BaseModel):
    figures: PupilMonthFigures

    # A pupil somebody answers for reads a narrower card than one who books
    # for themselves.
    has_parental_responsibility: bool


class ParentMonthSummaryResponse(BaseModel):
    children: list[PupilMonthFigures]
