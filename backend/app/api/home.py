from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

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
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.parental_responsibility import ParentalResponsibility
from app.models.presence import Presence
from app.models.student import Student
from app.repositories.person_repository import PersonRepository
from app.schemas.home import (
    ParentMonthSummaryResponse,
    PupilMonthFigures,
    StudentMonthSummaryResponse,
    TeacherMonthFigures,
    TeacherMonthSummaryResponse,
    WeekFigures,
)
from app.schemas.person import PersonOption
from app.services.availability_weeks import (
    AvailabilityWeek,
    teacher_weeks,
    weekly_average,
)
from app.services.compensation import (
    TermsTimeline,
    done_bands,
    load_terms,
    month_compensation,
)
from app.services.enrollment_spans import (
    EnrolledSpan,
    enrolled_days,
    enrolled_spans,
    enrolled_throughout,
)
from app.services.student_payments import current_tariff_kinds
from app.services.worked_hours import (
    days_of,
    minutes_of,
    published_pairs,
    span_minutes,
)

router = APIRouter(prefix="/home", tags=["home"])


# Month to date, today included, counted as statistics.py does so flags agree.
@dataclass(frozen=True)
class _Month:
    start: date
    now: datetime

    @classmethod
    def current(cls) -> "_Month":
        now = now_in_rome()

        return cls(start=now.date().replace(day=1), now=now)

    # Previous month up to the same day and hour; a day it never had becomes its last.
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

    # A stretch counts once it is over, not once it is scheduled.
    def is_over(self, day: date, end_time: time) -> bool:
        return day < self.today or (day == self.today and end_time <= self.now.time())


async def _pupil_figures(
    db: AsyncSession,
    tax_codes: Sequence[str],
    month: _Month,
    published: set[tuple[date, str]],
) -> dict[str, PupilMonthFigures]:
    if not tax_codes:
        return {}

    pupils = list(
        await db.scalars(
            select(Student.tax_code).where(Student.tax_code.in_(tax_codes)),
        )
    )
    tariffs = await current_tariff_kinds(db, pupils, month.today)

    people = await PersonRepository(db).get_options(pupils)

    async def presence_days(since: date, before: date) -> dict[str, int]:
        return {
            row.student_tax_code: row.days
            for row in await db.execute(
                select(
                    Presence.student_tax_code,
                    func.count(func.distinct(Presence.date)).label("days"),
                )
                .where(
                    Presence.student_tax_code.in_(pupils),
                    Presence.date >= since,
                    Presence.date < before,
                )
                .group_by(Presence.student_tax_code),
            )
        }

    presences = await presence_days(month.start, month.until)
    spans = await enrolled_spans(db, pupils)

    def weekly(tax_code: str) -> float:
        days = enrolled_days(spans.get(tax_code, []), month.start, month.until)

        return round(presences.get(tax_code, 0) / (days / 7), 1) if days else 0.0

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
            Presence.student_tax_code.in_(pupils),
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
                minutes_of(row.end_time) - minutes_of(row.start_time)
            )

    return {
        tax_code: PupilMonthFigures(
            student=PersonOption.model_validate(people[tax_code]),
            total_presences=presences.get(tax_code, 0),
            weekly_presences=weekly(tax_code),
            booked_presences=booked.get(tax_code, 0),
            lesson_minutes=minutes.get(tax_code, 0),
            tariff_kind=tariffs.get(tax_code),
        )
        for tax_code in pupils
    }


async def _teacher_weeks(
    db: AsyncSession,
    tax_code: str,
    spans: Sequence[EnrolledSpan],
    month: _Month,
) -> list[AvailabilityWeek]:
    return await teacher_weeks(
        db,
        tax_code,
        spans,
        month.start,
        month.end,
        month.today,
    )


# Confirmed where the band is, the calendar elsewhere; both modes together.
async def _worked_minutes(db: AsyncSession, tax_code: str, month: _Month) -> int:
    done = await done_bands(db, tax_code, month.start, month.end, month.is_over)

    return sum(span_minutes(spans) for spans in days_of(done).values())


async def _teacher_figures(
    db: AsyncSession,
    tax_code: str,
    month: _Month,
    timeline: TermsTimeline,
    weeks: Sequence[AvailabilityWeek],
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

    pay = await month_compensation(
        db,
        tax_code,
        month.start,
        month.is_over,
        timeline,
    )

    return TeacherMonthFigures(
        total_availabilities=total,
        weekly_availabilities=round(weekly_average(weeks), 1),
        worked_minutes=await _worked_minutes(db, tax_code, month),
        gross_compensation=pay.gross,
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

    timeline = await load_terms(db, identity.tax_code)
    spans = (await enrolled_spans(db, [identity.tax_code])).get(identity.tax_code, [])
    weeks = await _teacher_weeks(db, identity.tax_code, spans, month)
    figures = await _teacher_figures(db, identity.tax_code, month, timeline, weeks)
    short = sum(1 for week in weeks if week.is_short)
    current = next((week for week in weeks if week.is_open), None)

    return TeacherMonthSummaryResponse(
        **figures.model_dump(),
        is_below_monthly_threshold=(
            figures.total_availabilities < LOW_AVAILABILITY_MONTHLY_THRESHOLD
            and enrolled_throughout(spans, month.start, month.until)
        ),
        is_below_weekly_threshold=(
            bool(weeks) and weekly_average(weeks) < LOW_AVAILABILITY_WEEKLY_THRESHOLD
        ),
        short_week_count=short,
        current_week=(
            None
            if current is None
            else WeekFigures(given=current.given, required=current.required)
        ),
        last_month=await _teacher_figures(
            db,
            identity.tax_code,
            month.previous,
            timeline,
            await _teacher_weeks(db, identity.tax_code, spans, month.previous),
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
        await published_pairs(db, month.start, month.until),
    )

    guardian = await db.scalar(
        select(ParentalResponsibility.parent_tax_code)
        .where(ParentalResponsibility.child_tax_code == identity.tax_code)
        .limit(1),
    )

    own = figures[identity.tax_code]

    # Paid for by whoever answers for the pupil, who never reads the tariff.
    if guardian is not None:
        own = own.model_copy(update={"tariff_kind": None})

    return StudentMonthSummaryResponse(
        figures=own,
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
        await published_pairs(db, month.start, month.until),
    )

    return ParentMonthSummaryResponse(
        children=sorted(
            figures.values(),
            key=lambda child: (child.student.first_name, child.student.last_name),
        ),
    )
