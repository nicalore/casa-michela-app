from collections import defaultdict
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Final

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, require_role
from app.core.availability_thresholds import (
    LOW_AVAILABILITY_MONTHLY_THRESHOLD,
    LOW_AVAILABILITY_WEEKLY_THRESHOLD,
)
from app.core.booking_window import now_in_rome
from app.core.time_band import band_of
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.parental_responsibility import ParentalResponsibility
from app.models.presence import Presence
from app.models.room_supervision import RoomSupervision
from app.models.staff import Staff
from app.models.student import Student
from app.repositories.person_repository import PersonRepository
from app.schemas.home import (
    ParentMonthSummaryResponse,
    PupilMonthFigures,
    StudentMonthSummaryResponse,
    TeacherMonthFigures,
    TeacherMonthSummaryResponse,
)
from app.schemas.person import PersonOption

# What a person's home says about their own month; the desk-wide figures
# live in app/api/statistics.py.
router = APIRouter(prefix="/home", tags=["home"])

_MINUTES_PER_HOUR: Final[int] = 60
_CENTS: Final[Decimal] = Decimal("0.01")

_Stretch = tuple[date, time, time]


# The month so far: from its first day to today included, as the desk
# statistics count it, so a flag reads the same on both sides.
@dataclass(frozen=True)
class _Month:
    start: date
    now: datetime

    @classmethod
    def current(cls) -> "_Month":
        now = now_in_rome()

        return cls(start=now.date().replace(day=1), now=now)

    # The month before, lived up to the same day and hour: what a figure is
    # compared with. A day the shorter month never had becomes its last.
    @property
    def previous(self) -> "_Month":
        start = (self.start - timedelta(days=1)).replace(day=1)
        last = (self.start - timedelta(days=1)).day

        return _Month(
            start=start,
            now=self.now.replace(
                year=start.year,
                month=start.month,
                day=min(self.today.day, last),
            ),
        )

    @property
    def today(self) -> date:
        return self.now.date()

    # Tomorrow: the window is half-open.
    @property
    def until(self) -> date:
        return self.today + timedelta(days=1)

    # First day of the next month: the whole month is half-open too.
    @property
    def end(self) -> date:
        return (self.start + timedelta(days=32)).replace(day=1)

    @property
    def weeks(self) -> float:
        return (self.until - self.start).days / 7

    # A stretch counts once it is over, not once it is scheduled.
    def is_over(self, day: date, end_time: time) -> bool:
        return day < self.today or (day == self.today and end_time <= self.now.time())


def _minutes(moment: time) -> int:
    return moment.hour * _MINUTES_PER_HOUR + moment.minute


# Lessons of one teacher may overlap (two pupils, staggered), and a room
# shift runs across them: the day is measured as a union, not a sum.
def _union_minutes(stretches: Iterable[_Stretch]) -> int:
    by_day: dict[date, list[tuple[int, int]]] = defaultdict(list)

    for day, start, end in stretches:
        by_day[day].append((_minutes(start), _minutes(end)))

    total = 0

    for spans in by_day.values():
        spans.sort()
        current_start, current_end = spans[0]

        for start, end in spans[1:]:
            if start > current_end:
                total += current_end - current_start
                current_start, current_end = start, end
            else:
                current_end = max(current_end, end)

        total += current_end - current_start

    return total


async def _published_pairs(db: AsyncSession, month: _Month) -> set[tuple[date, str]]:
    rows = await db.execute(
        select(CalendarPublication.date, CalendarPublication.band).where(
            CalendarPublication.date >= month.start,
            CalendarPublication.date < month.until,
        ),
    )

    return {(row.date, row.band) for row in rows}


# Everything the published calendar had the teacher do so far this month.
async def _teacher_stretches(
    db: AsyncSession,
    tax_code: str,
    month: _Month,
    published: set[tuple[date, str]],
) -> list[_Stretch]:
    lessons = await db.execute(
        select(Lesson.date, Lesson.band, Lesson.start_time, Lesson.end_time)
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(
            Availability.teacher_tax_code == tax_code,
            Lesson.date >= month.start,
            Lesson.date <= month.today,
        ),
    )

    activities = await db.execute(
        select(
            CalendarActivity.date,
            CalendarActivity.band,
            CalendarActivity.start_time,
            CalendarActivity.end_time,
        )
        .join(Availability, Availability.id == CalendarActivity.availability_id)
        .where(
            Availability.teacher_tax_code == tax_code,
            CalendarActivity.date >= month.start,
            CalendarActivity.date <= month.today,
        ),
    )

    shifts = await db.execute(
        select(
            RoomSupervision.date,
            RoomSupervision.start_time,
            RoomSupervision.end_time,
        ).where(
            RoomSupervision.teacher_tax_code == tax_code,
            RoomSupervision.date >= month.start,
            RoomSupervision.date <= month.today,
        ),
    )

    rows = [
        *((row.date, row.band, row.start_time, row.end_time) for row in lessons),
        *((row.date, row.band, row.start_time, row.end_time) for row in activities),
        # A shift has no band of its own: it sits in the one it starts in.
        *(
            (row.date, str(band_of(row.start_time)), row.start_time, row.end_time)
            for row in shifts
        ),
    ]

    return [
        (day, start, end)
        for day, band, start, end in rows
        if (day, band) in published and month.is_over(day, end)
    ]


async def _pupil_figures(
    db: AsyncSession,
    tax_codes: Sequence[str],
    month: _Month,
    published: set[tuple[date, str]],
) -> dict[str, PupilMonthFigures]:
    if not tax_codes:
        return {}

    tariffs = {
        row.tax_code: row.homework_tariff
        for row in await db.execute(
            select(Student.tax_code, Student.homework_tariff).where(
                Student.tax_code.in_(tax_codes),
            ),
        )
    }

    people = await PersonRepository(db).get_options(tariffs)

    async def presence_days(since: date, before: date) -> dict[str, int]:
        return {
            row.student_tax_code: row.days
            for row in await db.execute(
                select(
                    Presence.student_tax_code,
                    func.count(func.distinct(Presence.date)).label("days"),
                )
                .where(
                    Presence.student_tax_code.in_(tariffs),
                    Presence.date >= since,
                    Presence.date < before,
                )
                .group_by(Presence.student_tax_code),
            )
        }

    presences = await presence_days(month.start, month.until)

    # Still to come: from tomorrow to the end of the month.
    booked = await presence_days(month.until, month.end)

    lessons = await db.execute(
        select(
            Presence.student_tax_code,
            Lesson.id,
            Lesson.date,
            Lesson.band,
            Lesson.start_time,
            Lesson.end_time,
        )
        .join(LessonBooking, LessonBooking.lesson_id == Lesson.id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
        .where(
            Presence.student_tax_code.in_(tariffs),
            Lesson.date >= month.start,
            Lesson.date <= month.today,
        ),
    )

    # Two subjects of one pupil can share a lesson: it is one hour, not two.
    counted: set[tuple[str, int]] = set()
    minutes: dict[str, int] = defaultdict(int)

    for row in lessons:
        key = (row.student_tax_code, row.id)

        if key in counted or (row.date, row.band) not in published:
            continue

        if month.is_over(row.date, row.end_time):
            counted.add(key)
            minutes[row.student_tax_code] += (
                _minutes(row.end_time) - _minutes(row.start_time)
            )

    return {
        tax_code: PupilMonthFigures(
            student=PersonOption.model_validate(people[tax_code]),
            total_presences=presences.get(tax_code, 0),
            weekly_presences=round(presences.get(tax_code, 0) / month.weeks, 1),
            booked_presences=booked.get(tax_code, 0),
            lesson_minutes=minutes.get(tax_code, 0),
            homework_tariff=tariff,
        )
        for tax_code, tariff in tariffs.items()
    }


async def _teacher_figures(
    db: AsyncSession,
    tax_code: str,
    month: _Month,
    rate: Decimal | None,
) -> TeacherMonthFigures:
    total = (
        await db.scalar(
            select(func.count(func.distinct(Availability.date))).where(
                Availability.teacher_tax_code == tax_code,
                Availability.mode == "presence",
                Availability.date >= month.start,
                Availability.date < month.until,
            ),
        )
        or 0
    )

    published = await _published_pairs(db, month)
    worked = _union_minutes(await _teacher_stretches(db, tax_code, month, published))

    return TeacherMonthFigures(
        total_availabilities=total,
        weekly_availabilities=round(total / month.weeks, 1),
        worked_minutes=worked,
        gross_compensation=(
            None
            if rate is None
            else (Decimal(worked) / _MINUTES_PER_HOUR * rate).quantize(
                _CENTS,
                rounding=ROUND_HALF_UP,
            )
        ),
    )


@router.get(
    "/teacher-month",
    response_model=TeacherMonthSummaryResponse,
    dependencies=[Depends(require_role("TEACHER"))],
)
async def get_teacher_month(
    identity: CurrentIdentity,
    db: DbSession,
) -> TeacherMonthSummaryResponse:
    month = _Month.current()

    # Today's rate for both months: what the pay would be, not what it was.
    rate = await db.scalar(
        select(Staff.gross_compensation).where(Staff.tax_code == identity.tax_code),
    )

    figures = await _teacher_figures(db, identity.tax_code, month, rate)
    weekly = figures.total_availabilities / month.weeks

    return TeacherMonthSummaryResponse(
        **figures.model_dump(),
        is_below_monthly_threshold=(
            figures.total_availabilities < LOW_AVAILABILITY_MONTHLY_THRESHOLD
        ),
        is_below_weekly_threshold=weekly < LOW_AVAILABILITY_WEEKLY_THRESHOLD,
        last_month=await _teacher_figures(
            db,
            identity.tax_code,
            month.previous,
            rate,
        ),
    )


@router.get(
    "/student-month",
    response_model=StudentMonthSummaryResponse,
    dependencies=[Depends(require_role("STUDENT"))],
)
async def get_student_month(
    identity: CurrentIdentity,
    db: DbSession,
) -> StudentMonthSummaryResponse:
    month = _Month.current()

    figures = await _pupil_figures(
        db,
        [identity.tax_code],
        month,
        await _published_pairs(db, month),
    )

    guardian = await db.scalar(
        select(ParentalResponsibility.parent_tax_code)
        .where(ParentalResponsibility.child_tax_code == identity.tax_code)
        .limit(1),
    )

    return StudentMonthSummaryResponse(
        figures=figures[identity.tax_code],
        has_parental_responsibility=guardian is not None,
    )


@router.get(
    "/parent-month",
    response_model=ParentMonthSummaryResponse,
    dependencies=[Depends(require_role("PARENT"))],
)
async def get_parent_month(
    identity: CurrentIdentity,
    db: DbSession,
) -> ParentMonthSummaryResponse:
    month = _Month.current()

    # Children who are not pupils have no month to sum up and are left out.
    figures = await _pupil_figures(
        db,
        sorted(identity.child_tax_codes),
        month,
        await _published_pairs(db, month),
    )

    return ParentMonthSummaryResponse(
        children=sorted(
            figures.values(),
            key=lambda child: (child.student.first_name, child.student.last_name),
        ),
    )
