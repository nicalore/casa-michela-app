from datetime import date, timedelta
from typing import Annotated, Any, Final

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import Select, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.core.booking_window import today_in_rome
from app.core.labels import (
    certification_type_label,
    course_type_label,
    education_level_label,
)
from app.models.administrator import Administrator
from app.models.association_subject import AssociationSubject
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.booking_teacher_preference import (
    BookingTeacherPreference,
    TeacherPreferenceTypeEnum,
)
from app.models.course_participant import CourseParticipant
from app.models.member import Member
from app.models.membership import Membership
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.ministry_subject import MinistrySubject
from app.models.person import Person
from app.models.presence import Presence
from app.models.psychologist import Psychologist
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.staff import Staff
from app.models.student import Student
from app.models.study_program import StudyProgram
from app.models.study_program_subject import StudyProgramSubject
from app.models.subject_requested import SubjectRequested
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence
from app.schemas.person import PersonOption
from app.schemas.statistics import (
    AgeDistributionItem,
    AreaDistributionItem,
    CertificationDistributionItem,
    CityDistributionItem,
    CourseDistributionItem,
    CurrentTotalsResponse,
    EducationDistributionItem,
    LowAvailabilityTeacherItem,
    MemberTrendItem,
    MonthlyCountItem,
    RequestedSubjectItem,
    RequestedSubjectRankings,
    RetentionRateItem,
    StudentPersonalStatisticsResponse,
    StudentPresenceRankItem,
    StudentPresenceStatisticsResponse,
    SubjectDistributionItem,
    TeacherAppreciationItem,
    TeacherAppreciationRankingResponse,
    TeacherAvailabilityRankItem,
    TeacherAvailabilityStatisticsResponse,
    TeacherPersonalStatisticsResponse,
    TeacherSubjectsStatisticsResponse,
)

router = APIRouter(
    prefix="/statistics",
    tags=["statistics"],
)

_MONTH_RESOLUTION: Final[str] = "month"
_UNKNOWN_AREA_LABEL: Final[str] = "Altra Area"
_TOP_SUBJECTS_LIMIT: Final[int] = 10
_TOP_PEOPLE_LIMIT: Final[int] = 10

_APPRECIATION_LIMIT: Final[int] = 5

# Calendars older than a year are deleted, so only 12 months back are askable.
_STATS_MONTHS_WINDOW: Final[int] = 12

_MONTH_OUT_OF_STATS_WINDOW_ERROR: Final[str] = (
    "Le statistiche coprono solo gli ultimi dodici mesi"
)

_INCOMPLETE_STATS_MONTH_ERROR: Final[str] = (
    "Indica anno e mese insieme, oppure nessuno dei due per gli ultimi "
    "dodici mesi"
)

_CONFLICTING_STATS_PERIOD_ERROR: Final[str] = (
    "Indica gli ultimi mesi oppure un mese preciso, non entrambi"
)

# Weekly slots below this flag a collaborating teacher.
_LOW_AVAILABILITY_WEEKLY_THRESHOLD: Final[int] = 2

# Monthly slots below this flag a teacher; only meaningful for a single-month period.
_LOW_AVAILABILITY_MONTHLY_THRESHOLD: Final[int] = 9

_TEACHER_NOT_FOUND_ERROR: Final[str] = "Docente non trovato"
_DISCIPLINE_NOT_FOUND_ERROR: Final[str] = "Disciplina non trovata"
_STUDENT_NOT_FOUND_ERROR: Final[str] = "Studente non trovato"

_ROLE_JOINS: Final[dict[str, tuple[tuple[Any, Any], ...]]] = {
    "administrator": (
        (Staff, Member.tax_code == Staff.tax_code),
        (Administrator, Staff.tax_code == Administrator.tax_code),
    ),
    "psychologist": (
        (Staff, Member.tax_code == Staff.tax_code),
        (Psychologist, Staff.tax_code == Psychologist.tax_code),
    ),
    "teacher": (
        (Staff, Member.tax_code == Staff.tax_code),
        (Teacher, Staff.tax_code == Teacher.tax_code),
    ),
    "student": ((Student, Member.tax_code == Student.tax_code),),
    "course_participant": (
        (CourseParticipant, Member.tax_code == CourseParticipant.tax_code),
    ),
}

# Upper bound of each bucket, in order; None marks the open-ended last one.
_AGE_BUCKETS: Final[tuple[tuple[int | None, str], ...]] = (
    (10, "< 11"),
    (14, "11-14"),
    (18, "15-18"),
    (25, "19-25"),
    (35, "26-35"),
    (50, "36-50"),
    (None, "> 50"),
)

_ENROLLMENT_TO_PROGRAM_JOIN: Final[Any] = and_(
    SchoolEnrollment.study_program_id == SchoolStudyProgram.study_program_id,
    SchoolEnrollment.school_id == SchoolStudyProgram.school_id,
)


def _apply_role_joins(stmt: Select[Any], role: str | None) -> Select[Any]:
    for target, onclause in _ROLE_JOINS.get(role or "", ()):
        stmt = stmt.join(target, onclause)

    return stmt


def _with_person_role(stmt: Select[Any], role: str) -> Select[Any]:
    return _apply_role_joins(
        stmt.join(Member, Person.tax_code == Member.tax_code),
        role,
    )


def _month_of(column: Any) -> Any:
    return func.extract("month", column)


def _age_group(age: int) -> str:
    for upper_bound, label in _AGE_BUCKETS:
        if upper_bound is None or age <= upper_bound:
            return label

    return _AGE_BUCKETS[-1][1]


def _area_label(area: Any) -> str:
    value = getattr(area, "value", None)

    if value is not None:
        return str(value)

    return str(area) if area else _UNKNOWN_AREA_LABEL


async def _count_memberships(
    db: AsyncSession,
    role: str | None,
    *,
    year: int,
    before_month: int | None = None,
    only_collaborating: bool = False,
) -> int:
    stmt = (
        select(func.count(Membership.member_tax_code))
        .join(Member)
        .where(Membership.year == year)
    )

    if before_month is not None:
        stmt = stmt.where(_month_of(Membership.start_date) < before_month)

    if only_collaborating:
        stmt = stmt.where(Member.collaborating_active.is_(True))

    return await db.scalar(_apply_role_joins(stmt, role)) or 0


async def _calculate_current_totals_dashboard(
    role: str | None,
    db: AsyncSession,
) -> CurrentTotalsResponse:
    today = date.today()
    year = today.year
    month = today.month

    members_now = await _count_memberships(db, role, year=year)
    collaborators_now = await _count_memberships(
        db,
        role,
        year=year,
        only_collaborating=True,
    )
    members_month_start = await _count_memberships(
        db,
        role,
        year=year,
        before_month=month,
    )
    collaborators_month_start = await _count_memberships(
        db,
        role,
        year=year,
        before_month=month,
        only_collaborating=True,
    )
    members_year_start = await _count_memberships(db, role, year=year - 1)
    collaborators_year_start = await _count_memberships(
        db,
        role,
        year=year - 1,
        only_collaborating=True,
    )

    percentage_members = None
    percentage_collaborators = None

    if role is not None:
        general_members = await _count_memberships(db, None, year=year)
        general_collaborators = await _count_memberships(
            db,
            None,
            year=year,
            only_collaborating=True,
        )

        percentage_members = (
            round(members_now / general_members * 100, 1)
            if general_members > 0
            else 0.0
        )
        percentage_collaborators = (
            round(collaborators_now / general_collaborators * 100, 1)
            if general_collaborators > 0
            else 0.0
        )

    return CurrentTotalsResponse(
        current_total_members=members_now,
        members_delta_month=members_now - members_month_start,
        members_delta_year=members_now - members_year_start,
        current_active_collaborators=collaborators_now,
        collab_delta_month=collaborators_now - collaborators_month_start,
        collab_delta_year=collaborators_now - collaborators_year_start,
        percentage_of_total_members=percentage_members,
        percentage_of_total_collaborators=percentage_collaborators,
    )


def _accumulate_monthly_trend(
    new_members_by_period: dict[tuple[int, int], int],
    start_year: int | None,
    end_year: int | None,
) -> list[MemberTrendItem]:
    years = [year for year, _ in new_members_by_period]
    first_year = start_year if start_year is not None else min(years, default=None)
    last_year = end_year if end_year is not None else max(years, default=None)

    if first_year is None or last_year is None:
        return []

    items: list[MemberTrendItem] = []

    for year in range(first_year, last_year + 1):
        # Memberships are yearly, so the running total resets each January.
        running_total = 0

        for month in range(1, 13):
            running_total += new_members_by_period.get((year, month), 0)
            items.append(MemberTrendItem(year=year, month=month, total_members=running_total))

    return items


async def _execute_trend(
    role: str | None,
    resolution: str,
    start_year: int | None,
    end_year: int | None,
    db: AsyncSession,
    *,
    only_collaborating: bool = False,
) -> list[MemberTrendItem]:
    by_month = resolution == _MONTH_RESOLUTION

    if by_month:
        query = (
            select(
                Membership.year,
                _month_of(Membership.start_date).label("month"),
                func.count(Membership.member_tax_code).label("total"),
            )
            .join(Member)
            .group_by(Membership.year, _month_of(Membership.start_date))
        )
    else:
        query = (
            select(
                Membership.year,
                func.count(Membership.member_tax_code).label("total"),
            )
            .join(Member)
            .group_by(Membership.year)
        )

    if only_collaborating:
        query = query.where(Member.collaborating_active.is_(True))

    query = _apply_role_joins(query, role)

    if start_year is not None:
        query = query.where(Membership.year >= start_year)

    if end_year is not None:
        query = query.where(Membership.year <= end_year)

    result = await db.execute(query)
    rows = result.all()

    if by_month:
        new_members_by_period = {
            (row.year, int(row.month)): row.total for row in rows if row.month
        }

        return _accumulate_monthly_trend(new_members_by_period, start_year, end_year)

    return [
        MemberTrendItem(year=row.year, total_members=row.total)
        for row in sorted(rows, key=lambda row: row.year)
    ]


async def _execute_retention_rate(
    role: str | None,
    year: int,
    db: AsyncSession,
) -> RetentionRateItem:
    previous_stmt = _apply_role_joins(
        select(Membership.member_tax_code)
        .join(Member)
        .where(Membership.year == year - 1),
        role,
    )
    previous = previous_stmt.subquery()

    previous_count = (
        await db.scalar(select(func.count(previous.c.member_tax_code))) or 0
    )

    if previous_count == 0:
        return RetentionRateItem(
            year=year,
            previous_year_members=0,
            retained_members=0,
            retention_rate_percentage=0.0,
        )

    retained_stmt = _apply_role_joins(
        select(func.count(Membership.member_tax_code))
        .join(Member)
        .where(
            Membership.year == year,
            Membership.member_tax_code.in_(select(previous.c.member_tax_code)),
        ),
        role,
    )
    retained_count = await db.scalar(retained_stmt) or 0

    return RetentionRateItem(
        year=year,
        previous_year_members=previous_count,
        retained_members=retained_count,
        retention_rate_percentage=round(retained_count / previous_count * 100.0, 2),
    )


async def _execute_collaborating_retention(
    role: str | None,
    year: int,
    month: int,
    db: AsyncSession,
) -> RetentionRateItem:
    previous_month = 12 if month == 1 else month - 1
    previous_year = year - 1 if month == 1 else year

    previous_stmt = _apply_role_joins(
        select(Membership.member_tax_code)
        .join(Member)
        .where(
            Membership.year == previous_year,
            _month_of(Membership.start_date) <= previous_month,
            Member.collaborating_active.is_(True),
        ),
        role,
    )
    previous = previous_stmt.subquery()

    previous_count = (
        await db.scalar(select(func.count(previous.c.member_tax_code))) or 0
    )

    if previous_count == 0:
        return RetentionRateItem(
            year=year,
            month=month,
            previous_year_members=0,
            retained_members=0,
            retention_rate_percentage=0.0,
        )

    retained_stmt = _apply_role_joins(
        select(func.count(Membership.member_tax_code))
        .join(Member)
        .where(
            Membership.year == year,
            _month_of(Membership.start_date) <= month,
            Member.collaborating_active.is_(True),
            Membership.member_tax_code.in_(select(previous.c.member_tax_code)),
        ),
        role,
    )
    retained_count = await db.scalar(retained_stmt) or 0

    return RetentionRateItem(
        year=year,
        month=month,
        previous_year_members=previous_count,
        retained_members=retained_count,
        retention_rate_percentage=round(retained_count / previous_count * 100.0, 2),
    )


def _month_index(year: int, month: int) -> int:
    return year * 12 + month - 1


def _first_day_of_index(index: int) -> date:
    return date(index // 12, index % 12 + 1, 1)


# Half-open day interval: the last `months`, one named month, or the full twelve.
def _stats_window(
    months: int | None,
    year: int | None,
    month: int | None,
) -> tuple[date, date]:
    today = today_in_rome()
    current = _month_index(today.year, today.month)
    oldest = current - (_STATS_MONTHS_WINDOW - 1)

    if months is not None:
        if year is not None or month is not None:
            raise ValueError(_CONFLICTING_STATS_PERIOD_ERROR)

        return (
            _first_day_of_index(current - (months - 1)),
            _first_day_of_index(current + 1),
        )

    if year is None and month is None:
        return _first_day_of_index(oldest), _first_day_of_index(current + 1)

    if year is None or month is None:
        raise ValueError(_INCOMPLETE_STATS_MONTH_ERROR)

    selected = _month_index(year, month)

    if not oldest <= selected <= current:
        raise ValueError(_MONTH_OUT_OF_STATS_WINDOW_ERROR)

    return _first_day_of_index(selected), _first_day_of_index(selected + 1)


# Counts and averages stop at today, so the current month is not diluted by its future.
def _elapsed_window(window: tuple[date, date]) -> tuple[date, date]:
    start, end = window
    tomorrow = today_in_rome() + timedelta(days=1)

    return start, min(end, tomorrow)


def _weeks_of(window: tuple[date, date]) -> float:
    start, end = _elapsed_window(window)

    return max((end - start).days, 0) / 7


def _person_option_of(row: Any) -> PersonOption:
    return PersonOption(
        tax_code=row.tax_code,
        first_name=row.first_name,
        last_name=row.last_name,
        profile_image_url=row.profile_image_url,
    )


# Dated by Presence.date, and includes teachers who no longer collaborate.
async def _appreciation_ranking(
    db: AsyncSession,
    preference_type: TeacherPreferenceTypeEnum,
    window: tuple[date, date],
) -> list[TeacherAppreciationItem]:
    start, end = window
    requests = func.count(BookingTeacherPreference.booking_id)

    query = (
        select(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
            requests.label("request_count"),
        )
        .select_from(BookingTeacherPreference)
        .join(Booking, Booking.id == BookingTeacherPreference.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
        .join(Person, Person.tax_code == BookingTeacherPreference.teacher_tax_code)
        .where(
            BookingTeacherPreference.preference_type == preference_type,
            Presence.date >= start,
            Presence.date < end,
        )
        .group_by(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
        )
        .order_by(requests.desc(), Person.last_name, Person.first_name)
        .limit(_APPRECIATION_LIMIT)
    )

    result = await db.execute(query)

    return [
        TeacherAppreciationItem(
            teacher=_person_option_of(row),
            request_count=row.request_count,
        )
        for row in result.all()
    ]


@router.get("/general/current-totals", response_model=CurrentTotalsResponse)
async def get_general_current_totals(db: DbSession) -> CurrentTotalsResponse:
    return await _calculate_current_totals_dashboard(None, db)


@router.get("/general/members-trend", response_model=list[MemberTrendItem])
async def get_general_members_trend(
    db: DbSession,
    resolution: Annotated[str, Query()] = "year",
    start_year: Annotated[int | None, Query()] = None,
    end_year: Annotated[int | None, Query()] = None,
) -> list[MemberTrendItem]:
    return await _execute_trend(None, resolution, start_year, end_year, db)


@router.get("/general/collaborating-trend", response_model=list[MemberTrendItem])
async def get_general_collaborating_trend(
    db: DbSession,
    resolution: Annotated[str, Query()] = "year",
    start_year: Annotated[int | None, Query()] = None,
    end_year: Annotated[int | None, Query()] = None,
) -> list[MemberTrendItem]:
    return await _execute_trend(
        None,
        resolution,
        start_year,
        end_year,
        db,
        only_collaborating=True,
    )


@router.get("/general/retention-rate", response_model=RetentionRateItem)
async def get_general_retention_rate(
    db: DbSession,
    year: Annotated[int, Query()],
) -> RetentionRateItem:
    return await _execute_retention_rate(None, year, db)


@router.get("/general/collaborating-retention", response_model=RetentionRateItem)
async def get_general_collaborating_retention(
    db: DbSession,
    year: Annotated[int, Query()],
    month: Annotated[int, Query()],
) -> RetentionRateItem:
    return await _execute_collaborating_retention(None, year, month, db)


@router.get("/role/current-totals", response_model=CurrentTotalsResponse)
async def get_role_current_totals(
    db: DbSession,
    role: Annotated[str, Query()],
) -> CurrentTotalsResponse:
    return await _calculate_current_totals_dashboard(role, db)


@router.get("/role/members-trend", response_model=list[MemberTrendItem])
async def get_role_members_trend(
    db: DbSession,
    role: Annotated[str, Query()],
    resolution: Annotated[str, Query()] = "year",
    start_year: Annotated[int | None, Query()] = None,
    end_year: Annotated[int | None, Query()] = None,
) -> list[MemberTrendItem]:
    return await _execute_trend(role, resolution, start_year, end_year, db)


@router.get("/role/collaborating-trend", response_model=list[MemberTrendItem])
async def get_role_collaborating_trend(
    db: DbSession,
    role: Annotated[str, Query()],
    resolution: Annotated[str, Query()] = "year",
    start_year: Annotated[int | None, Query()] = None,
    end_year: Annotated[int | None, Query()] = None,
) -> list[MemberTrendItem]:
    return await _execute_trend(
        role,
        resolution,
        start_year,
        end_year,
        db,
        only_collaborating=True,
    )


@router.get("/role/retention-rate", response_model=RetentionRateItem)
async def get_role_retention_rate(
    db: DbSession,
    role: Annotated[str, Query()],
    year: Annotated[int, Query()],
) -> RetentionRateItem:
    return await _execute_retention_rate(role, year, db)


@router.get("/role/collaborating-retention", response_model=RetentionRateItem)
async def get_role_collaborating_retention(
    db: DbSession,
    role: Annotated[str, Query()],
    year: Annotated[int, Query()],
    month: Annotated[int, Query()],
) -> RetentionRateItem:
    return await _execute_collaborating_retention(role, year, month, db)


@router.get("/role/city-distribution", response_model=list[CityDistributionItem])
async def get_role_city_distribution(
    db: DbSession,
    role: Annotated[str, Query()],
) -> list[CityDistributionItem]:
    query = select(
        Person.residence_city.label("city"),
        func.count(Person.tax_code).label("member_count"),
    ).group_by(Person.residence_city)

    query = _with_person_role(query, role)
    query = query.order_by(func.count(Person.tax_code).desc())

    result = await db.execute(query)

    return [
        CityDistributionItem(city=row.city, count=row.member_count)
        for row in result.all()
    ]


@router.get("/role/age-distribution", response_model=list[AgeDistributionItem])
async def get_role_age_distribution(
    db: DbSession,
    role: Annotated[str, Query()],
) -> list[AgeDistributionItem]:
    query = _with_person_role(select(Person.birth_date), role)
    result = await db.execute(query)
    birth_dates = result.scalars().all()

    buckets = {label: 0 for _, label in _AGE_BUCKETS}
    today = date.today()

    for birth_date in birth_dates:
        age = (
            today.year
            - birth_date.year
            - ((today.month, today.day) < (birth_date.month, birth_date.day))
        )
        buckets[_age_group(age)] += 1

    return [
        AgeDistributionItem(age_group=label, count=count)
        for label, count in buckets.items()
        if count > 0
    ]


@router.get(
    "/students/education-distribution",
    response_model=list[EducationDistributionItem],
)
async def get_student_education_distribution(
    db: DbSession,
    distribution_type: Annotated[str, Query()] = "school",
) -> list[EducationDistributionItem]:
    query = select(
        func.count(func.distinct(Student.tax_code)).label("student_count")
    ).join(SchoolEnrollment, Student.tax_code == SchoolEnrollment.student_tax_code)

    label_column = None

    if distribution_type == "school":
        query = query.join(
            SchoolStudyProgram, _ENROLLMENT_TO_PROGRAM_JOIN
        ).join(School, SchoolStudyProgram.school_id == School.id)
        label_column = School.name

    elif distribution_type in ("program", "level"):
        query = query.join(
            SchoolStudyProgram, _ENROLLMENT_TO_PROGRAM_JOIN
        ).join(StudyProgram, SchoolStudyProgram.study_program_id == StudyProgram.id)
        # concat_ws skips a null sector.
        label_column = (
            func.concat_ws(" | ", StudyProgram.sector, StudyProgram.name)
            if distribution_type == "program"
            else StudyProgram.level
        )

    if label_column is not None:
        query = query.add_columns(label_column.label("label")).group_by(label_column)

    query = query.order_by(func.count(func.distinct(Student.tax_code)).desc())
    result = await db.execute(query)

    return [
        EducationDistributionItem(
            label=(
                education_level_label(row.label)
                if distribution_type == "level"
                else row.label
            ),
            count=row.student_count,
        )
        for row in result.all()
    ]


@router.get(
    "/students/certification-distribution",
    response_model=list[CertificationDistributionItem],
)
async def get_student_certification_distribution(
    db: DbSession,
) -> list[CertificationDistributionItem]:
    # One count per certification, not per pupil, so the slices exceed the pupil count.
    kind = func.unnest(Student.certification_types).label("kind")
    certified = select(kind).subquery()

    result = await db.execute(
        select(certified.c.kind, func.count().label("student_count"))
        .group_by(certified.c.kind)
        .order_by(func.count().desc()),
    )

    distribution = [
        CertificationDistributionItem(
            label=certification_type_label(row.kind),
            count=row.student_count,
        )
        for row in result.all()
    ]

    # unnest yields nothing for an empty set, so uncertified pupils are counted apart.
    without = await db.scalar(
        select(func.count(Student.tax_code)).where(
            func.cardinality(Student.certification_types) == 0
        ),
    )

    if without:
        distribution.append(
            CertificationDistributionItem(
                label=certification_type_label(None),
                count=without,
            )
        )

    return sorted(distribution, key=lambda item: item.count, reverse=True)


@router.get(
    "/teachers/subjects-statistics",
    response_model=TeacherSubjectsStatisticsResponse,
)
async def get_teacher_subjects_statistics(
    db: DbSession,
    ranking_mode: Annotated[str, Query()] = "absolute",
) -> TeacherSubjectsStatisticsResponse:
    active_teachers = (
        select(Teacher.tax_code)
        .join(Staff)
        .join(Member)
        .where(Member.collaborating_active.is_(True))
        .subquery()
    )

    competences_query = (
        select(
            TeachingCompetence.teacher_tax_code,
            TeachingCompetence.association_subject_id,
            TeachingCompetence.study_program_id,
            AssociationSubject.name.label("subject_name"),
            AssociationSubject.area,
            func.concat_ws(" | ", StudyProgram.sector, StudyProgram.name).label(
                "program_name"
            ),
        )
        .join(
            AssociationSubject,
            TeachingCompetence.association_subject_id == AssociationSubject.id,
        )
        .join(StudyProgram, TeachingCompetence.study_program_id == StudyProgram.id)
        .where(TeachingCompetence.teacher_tax_code.in_(select(active_teachers)))
    )

    result = await db.execute(competences_query)

    subjects_by_teacher: dict[str, set[int]] = {}
    teachers_by_group: dict[str, set[str]] = {}
    subject_name_by_group: dict[str, str] = {}
    program_name_by_group: dict[str, str | None] = {}
    teachers_by_area: dict[str, set[str]] = {}
    teachers_by_subject: dict[int, set[str]] = {}

    for row in result.all():
        teacher_tax_code = row.teacher_tax_code
        subject_id = row.association_subject_id

        subjects_by_teacher.setdefault(teacher_tax_code, set()).add(subject_id)
        teachers_by_subject.setdefault(subject_id, set()).add(teacher_tax_code)

        if ranking_mode == "program":
            group_key = f"{subject_id}-{row.study_program_id}"
            program_name_by_group[group_key] = row.program_name
        else:
            group_key = str(subject_id)
            program_name_by_group[group_key] = None

        subject_name_by_group[group_key] = row.subject_name
        teachers_by_group.setdefault(group_key, set()).add(teacher_tax_code)

        teachers_by_area.setdefault(_area_label(row.area), set()).add(teacher_tax_code)

    total_teachers = len(subjects_by_teacher)
    total_subjects = len(teachers_by_subject)

    average_subjects_per_teacher = (
        sum(len(subjects) for subjects in subjects_by_teacher.values()) / total_teachers
        if total_teachers > 0
        else 0.0
    )
    average_teachers_per_subject = (
        sum(len(teachers) for teachers in teachers_by_subject.values()) / total_subjects
        if total_subjects > 0
        else 0.0
    )

    # The universe must include groups with zero teachers for the least-covered ranking.
    group_labels: dict[str, tuple[str, str | None]] = {}

    if ranking_mode == "program":
        universe_result = await db.execute(
            select(
                AssociationSubject.id,
                AssociationSubject.name,
                StudyProgram.id,
                func.concat_ws(" | ", StudyProgram.sector, StudyProgram.name),
            )
            .select_from(MinistryAssociationSubject)
            .join(
                StudyProgramSubject,
                StudyProgramSubject.ministry_subject_id
                == MinistryAssociationSubject.ministry_subject_id,
            )
            .join(
                AssociationSubject,
                AssociationSubject.id
                == MinistryAssociationSubject.association_subject_id,
            )
            .join(
                StudyProgram,
                StudyProgram.id == StudyProgramSubject.study_program_id,
            )
            .distinct()
        )
        for subject_id, subject_name, program_id, program_name in universe_result.all():
            group_labels[f"{subject_id}-{program_id}"] = (subject_name, program_name)
    else:
        universe_result = await db.execute(
            select(AssociationSubject.id, AssociationSubject.name)
        )
        for subject_id, subject_name in universe_result.all():
            group_labels[str(subject_id)] = (subject_name, None)

    # Keep covered groups missing from the universe (stale taxonomy mappings).
    for key in teachers_by_group:
        group_labels.setdefault(
            key, (subject_name_by_group[key], program_name_by_group[key])
        )

    subject_counts = [
        SubjectDistributionItem(
            name=subject_name,
            program_name=program_name,
            count=len(teachers_by_group.get(key, set())),
        )
        for key, (subject_name, program_name) in group_labels.items()
    ]

    top_subjects = sorted(
        subject_counts,
        key=lambda item: (-item.count, item.name, item.program_name or ""),
    )[:_TOP_SUBJECTS_LIMIT]
    bottom_subjects = sorted(
        subject_counts,
        key=lambda item: (item.count, item.name, item.program_name or ""),
    )[:_TOP_SUBJECTS_LIMIT]

    area_distribution = [
        AreaDistributionItem(
            area=area,
            count=len(teachers),
            percentage=round(
                len(teachers) / total_teachers * 100 if total_teachers > 0 else 0.0,
                1,
            ),
        )
        for area, teachers in teachers_by_area.items()
    ]
    area_distribution.sort(key=lambda item: item.count, reverse=True)

    return TeacherSubjectsStatisticsResponse(
        avg_subjects_per_teacher=round(average_subjects_per_teacher, 1),
        avg_teachers_per_subject=round(average_teachers_per_subject, 1),
        top_10_subjects=top_subjects,
        bottom_10_subjects=bottom_subjects,
        area_distribution=area_distribution,
    )


@router.get(
    "/teachers/appreciation-ranking",
    response_model=TeacherAppreciationRankingResponse,
)
async def get_teacher_appreciation_ranking(
    db: DbSession,
    months: Annotated[int | None, Query(ge=1, le=12)] = None,
    year: Annotated[int | None, Query()] = None,
    month: Annotated[int | None, Query(ge=1, le=12)] = None,
) -> TeacherAppreciationRankingResponse:
    window = _stats_window(months, year, month)

    return TeacherAppreciationRankingResponse(
        most_appreciated=await _appreciation_ranking(
            db,
            TeacherPreferenceTypeEnum.PREFERRED,
            window,
        ),
        least_appreciated=await _appreciation_ranking(
            db,
            TeacherPreferenceTypeEnum.NOT_PREFERRED,
            window,
        ),
    )


def _availability_counts_stmt(window: tuple[date, date]) -> Select[Any]:
    start, end = _elapsed_window(window)

    return (
        select(
            Availability.teacher_tax_code,
            func.count(Availability.id).label("availability_count"),
        )
        .where(Availability.date >= start, Availability.date < end)
        .group_by(Availability.teacher_tax_code)
    )


# Active collaborators under the threshold; outer-joined so those with zero slots appear.
async def _teachers_under(
    db: AsyncSession,
    window: tuple[date, date],
    threshold: int,
) -> list[LowAvailabilityTeacherItem]:
    counts = _availability_counts_stmt(window).subquery()
    given = func.coalesce(counts.c.availability_count, 0)
    weeks = _weeks_of(window)

    query = (
        select(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
            given.label("given"),
        )
        .select_from(Teacher)
        .join(Staff, Staff.tax_code == Teacher.tax_code)
        .join(Member, Member.tax_code == Staff.tax_code)
        .join(Person, Person.tax_code == Teacher.tax_code)
        .outerjoin(counts, counts.c.teacher_tax_code == Teacher.tax_code)
        .where(Member.collaborating_active.is_(True), given < threshold)
        .order_by(given, Person.last_name, Person.first_name)
    )

    result = await db.execute(query)

    return [
        LowAvailabilityTeacherItem(
            teacher=_person_option_of(row),
            weekly_average=round(row.given / weeks, 1) if weeks > 0 else 0.0,
            availability_count=row.given,
        )
        for row in result.all()
    ]


@router.get(
    "/teachers/availability-statistics",
    response_model=TeacherAvailabilityStatisticsResponse,
)
async def get_teacher_availability_statistics(
    db: DbSession,
    months: Annotated[int | None, Query(ge=1, le=12)] = None,
    year: Annotated[int | None, Query()] = None,
    month: Annotated[int | None, Query(ge=1, le=12)] = None,
) -> TeacherAvailabilityStatisticsResponse:
    window = _stats_window(months, year, month)
    weeks = _weeks_of(window)

    # One named month or "the last month": both are a single calendar month.
    is_single_month = months == 1 or (year is not None and month is not None)

    counts = _availability_counts_stmt(window).subquery()

    # sum() comes back from Postgres as a Decimal.
    total_availabilities = int(
        await db.scalar(
            select(func.coalesce(func.sum(counts.c.availability_count), 0)),
        )
        or 0
    )

    weekly_average = total_availabilities / weeks if weeks > 0 else 0.0

    top_query = (
        select(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
            counts.c.availability_count,
        )
        .join(Person, Person.tax_code == counts.c.teacher_tax_code)
        .order_by(
            counts.c.availability_count.desc(),
            Person.last_name,
            Person.first_name,
        )
        .limit(_TOP_PEOPLE_LIMIT)
    )
    top_result = await db.execute(top_query)

    return TeacherAvailabilityStatisticsResponse(
        weekly_average=round(weekly_average, 1),
        total_availabilities=total_availabilities,
        top_teachers=[
            TeacherAvailabilityRankItem(
                teacher=_person_option_of(row),
                availability_count=row.availability_count,
            )
            for row in top_result.all()
        ],
        low_availability_teachers=await _teachers_under(
            db,
            window,
            round(_LOW_AVAILABILITY_WEEKLY_THRESHOLD * weeks),
        ),
        is_single_month=is_single_month,
        low_monthly_teachers=(
            await _teachers_under(db, window, _LOW_AVAILABILITY_MONTHLY_THRESHOLD)
            if is_single_month
            else []
        ),
    )


# Standard competition ranking: equal counts share a place.
def _rank_among(counts: dict[str, int], tax_code: str) -> int | None:
    mine = counts.get(tax_code, 0)

    if mine == 0:
        return None

    return 1 + sum(1 for count in counts.values() if count > mine)


async def _preference_counts(
    db: AsyncSession,
    preference_type: TeacherPreferenceTypeEnum,
    window: tuple[date, date],
) -> dict[str, int]:
    start, end = window

    result = await db.execute(
        select(
            BookingTeacherPreference.teacher_tax_code,
            func.count(BookingTeacherPreference.booking_id),
        )
        .join(Booking, Booking.id == BookingTeacherPreference.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
        .where(
            BookingTeacherPreference.preference_type == preference_type,
            Presence.date >= start,
            Presence.date < end,
        )
        .group_by(BookingTeacherPreference.teacher_tax_code)
    )

    return dict(result.all())


@router.get(
    "/teachers/{tax_code}/personal-statistics",
    response_model=TeacherPersonalStatisticsResponse,
)
async def get_teacher_personal_statistics(
    db: DbSession,
    tax_code: str,
    months: Annotated[int | None, Query(ge=1, le=12)] = None,
    year: Annotated[int | None, Query()] = None,
    month: Annotated[int | None, Query(ge=1, le=12)] = None,
) -> TeacherPersonalStatisticsResponse:
    if await db.scalar(select(Teacher.tax_code).where(Teacher.tax_code == tax_code)) is None:
        raise HTTPException(status_code=404, detail=_TEACHER_NOT_FOUND_ERROR)

    window = _stats_window(months, year, month)
    start, end = _elapsed_window(window)
    is_single_month = months == 1 or (year is not None and month is not None)

    total = (
        await db.scalar(
            select(func.count(Availability.id)).where(
                Availability.teacher_tax_code == tax_code,
                Availability.date >= start,
                Availability.date < end,
            ),
        )
        or 0
    )
    weeks = _weeks_of(window)
    weekly_average = total / weeks if weeks > 0 else 0.0

    # The chart is always the last twelve months, whatever period was requested.
    trend_start, trend_end = _elapsed_window(_stats_window(None, None, None))

    trend_rows = (
        await db.execute(
            select(
                func.extract("year", Availability.date).label("year"),
                _month_of(Availability.date).label("month"),
                func.count(Availability.id).label("availability_count"),
            )
            .where(
                Availability.teacher_tax_code == tax_code,
                Availability.date >= trend_start,
                Availability.date < trend_end,
            )
            .group_by(
                func.extract("year", Availability.date),
                _month_of(Availability.date),
            ),
        )
    ).all()
    monthly_trend = _pad_monthly(
        {
            (int(row.year), int(row.month)): row.availability_count
            for row in trend_rows
        },
    )

    preferred = await _preference_counts(
        db, TeacherPreferenceTypeEnum.PREFERRED, window
    )
    not_preferred = await _preference_counts(
        db, TeacherPreferenceTypeEnum.NOT_PREFERRED, window
    )

    return TeacherPersonalStatisticsResponse(
        weekly_average=round(weekly_average, 1),
        total_availabilities=total,
        monthly_trend=monthly_trend,
        is_below_weekly_threshold=weekly_average < _LOW_AVAILABILITY_WEEKLY_THRESHOLD,
        is_single_month=is_single_month,
        is_below_monthly_threshold=(
            is_single_month and total < _LOW_AVAILABILITY_MONTHLY_THRESHOLD
        ),
        preferred_count=preferred.get(tax_code, 0),
        preferred_rank=_rank_among(preferred, tax_code),
        not_preferred_count=not_preferred.get(tax_code, 0),
        not_preferred_rank=_rank_among(not_preferred, tax_code),
    )


# One row per (student, day): two presences on the same day count once.
def _presence_days_stmt(window: tuple[date, date]) -> Select[Any]:
    start, end = _elapsed_window(window)

    return (
        select(Presence.student_tax_code, Presence.date)
        .where(Presence.date >= start, Presence.date < end)
        .distinct()
    )


def _pad_monthly(counts_by_month: dict[tuple[int, int], int]) -> list[MonthlyCountItem]:
    window = _stats_window(None, None, None)
    first_index = _month_index(window[0].year, window[0].month)
    trend: list[MonthlyCountItem] = []

    for index in range(first_index, first_index + _STATS_MONTHS_WINDOW):
        month_start = _first_day_of_index(index)
        trend.append(
            MonthlyCountItem(
                year=month_start.year,
                month=month_start.month,
                count=counts_by_month.get((month_start.year, month_start.month), 0),
            ),
        )

    return trend


def _ranked(rows: Any, limit: int) -> list[RequestedSubjectItem]:
    counts: dict[str, int] = {}

    for name, count in rows:
        counts[name] = counts.get(name, 0) + count

    # Share taken over the whole kind, before the list is cut to its top places.
    total = sum(counts.values())

    items = [
        RequestedSubjectItem(
            name=name,
            request_count=count,
            percentage=round(count / total * 100, 1) if total > 0 else 0.0,
        )
        for name, count in counts.items()
    ]
    items.sort(key=lambda item: (-item.request_count, item.name))

    return items[:limit]


# A ministry request counts in both the subject ranking and the discipline one.
async def _requested_subjects(
    db: AsyncSession,
    window: tuple[date, date],
    *,
    student_tax_code: str | None = None,
    limit: int,
) -> RequestedSubjectRankings:
    start, end = window

    def bookings_in_window(stmt: Select[Any]) -> Select[Any]:
        stmt = stmt.join(Presence, Presence.id == Booking.presence_id).where(
            Presence.date >= start,
            Presence.date < end,
        )

        if student_tax_code is not None:
            stmt = stmt.where(Presence.student_tax_code == student_tax_code)

        return stmt

    direct_rows = (
        await db.execute(
            bookings_in_window(
                select(AssociationSubject.name, func.count(Booking.id))
                .join(
                    AssociationSubject,
                    AssociationSubject.id == Booking.association_subject_id,
                )
                .where(Booking.association_subject_id.is_not(None)),
            ).group_by(AssociationSubject.name),
        )
    ).all()

    ministry_discipline_rows = (
        await db.execute(
            bookings_in_window(
                select(
                    AssociationSubject.name,
                    func.count(func.distinct(SubjectRequested.booking_id)),
                )
                .select_from(SubjectRequested)
                .join(Booking, Booking.id == SubjectRequested.booking_id)
                .join(
                    AssociationSubject,
                    AssociationSubject.id == SubjectRequested.association_subject_id,
                ),
            ).group_by(AssociationSubject.name),
        )
    ).all()

    # Counted per booking, not per row: one request names its subject once.
    ministry_subject_rows = (
        await db.execute(
            bookings_in_window(
                select(
                    MinistrySubject.name,
                    func.count(func.distinct(SubjectRequested.booking_id)),
                )
                .select_from(SubjectRequested)
                .join(Booking, Booking.id == SubjectRequested.booking_id)
                .join(
                    MinistrySubject,
                    MinistrySubject.id == SubjectRequested.ministry_subject_id,
                ),
            ).group_by(MinistrySubject.name),
        )
    ).all()

    service_rows = (
        await db.execute(
            bookings_in_window(
                select(Booking.service_name, func.count(Booking.id)).where(
                    Booking.service_name.is_not(None),
                ),
            ).group_by(Booking.service_name),
        )
    ).all()

    return RequestedSubjectRankings(
        ministry_subjects=_ranked(ministry_subject_rows, limit),
        disciplines=_ranked([*direct_rows, *ministry_discipline_rows], limit),
        services=_ranked(service_rows, limit),
    )


@router.get(
    "/students/presence-statistics",
    response_model=StudentPresenceStatisticsResponse,
)
async def get_student_presence_statistics(
    db: DbSession,
    months: Annotated[int | None, Query(ge=1, le=12)] = None,
    year: Annotated[int | None, Query()] = None,
    month: Annotated[int | None, Query(ge=1, le=12)] = None,
) -> StudentPresenceStatisticsResponse:
    window = _stats_window(months, year, month)
    days = _presence_days_stmt(window).subquery()

    totals_row = (
        await db.execute(
            select(
                func.count(),
                func.count(func.distinct(days.c.date)),
            ).select_from(days)
        )
    ).one()
    total_presence_days, distinct_dates = totals_row

    # Averaged over days somebody came, not over calendar days.
    daily_average = (
        total_presence_days / distinct_dates if distinct_dates > 0 else 0.0
    )

    top_query = (
        select(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
            func.count().label("presence_days"),
        )
        .select_from(days)
        .join(Person, Person.tax_code == days.c.student_tax_code)
        .group_by(
            Person.tax_code,
            Person.first_name,
            Person.last_name,
            Person.profile_image_url,
        )
        .order_by(func.count().desc(), Person.last_name, Person.first_name)
        .limit(_TOP_PEOPLE_LIMIT)
    )
    top_result = await db.execute(top_query)

    return StudentPresenceStatisticsResponse(
        daily_average=round(daily_average, 1),
        total_presence_days=total_presence_days,
        top_students=[
            StudentPresenceRankItem(
                student=_person_option_of(row),
                presence_days=row.presence_days,
            )
            for row in top_result.all()
        ],
        requested=await _requested_subjects(db, window, limit=_TOP_SUBJECTS_LIMIT),
    )


@router.get(
    "/students/discipline-trend",
    response_model=list[MonthlyCountItem],
)
async def get_discipline_request_trend(
    db: DbSession,
    association_subject_id: Annotated[int, Query()],
) -> list[MonthlyCountItem]:
    if (
        await db.scalar(
            select(AssociationSubject.id).where(
                AssociationSubject.id == association_subject_id,
            ),
        )
        is None
    ):
        raise HTTPException(status_code=404, detail=_DISCIPLINE_NOT_FOUND_ERROR)

    start, end = _elapsed_window(_stats_window(None, None, None))

    # Direct and ministry-nested requests both count; distinct, so twice named is one.
    asked_directly = select(Booking.id).where(
        Booking.association_subject_id == association_subject_id,
    )
    asked_within = select(SubjectRequested.booking_id).where(
        SubjectRequested.association_subject_id == association_subject_id,
    )

    rows = (
        await db.execute(
            select(
                func.extract("year", Presence.date).label("year"),
                _month_of(Presence.date).label("month"),
                func.count(func.distinct(Booking.id)).label("request_count"),
            )
            .join(Presence, Presence.id == Booking.presence_id)
            .where(
                Presence.date >= start,
                Presence.date < end,
                Booking.id.in_(asked_directly.union(asked_within)),
            )
            .group_by(
                func.extract("year", Presence.date),
                _month_of(Presence.date),
            ),
        )
    ).all()

    return _pad_monthly(
        {(int(row.year), int(row.month)): row.request_count for row in rows},
    )


@router.get(
    "/students/{tax_code}/personal-statistics",
    response_model=StudentPersonalStatisticsResponse,
)
async def get_student_personal_statistics(
    db: DbSession,
    tax_code: str,
    months: Annotated[int | None, Query(ge=1, le=12)] = None,
    year: Annotated[int | None, Query()] = None,
    month: Annotated[int | None, Query(ge=1, le=12)] = None,
) -> StudentPersonalStatisticsResponse:
    if await db.scalar(select(Student.tax_code).where(Student.tax_code == tax_code)) is None:
        raise HTTPException(status_code=404, detail=_STUDENT_NOT_FOUND_ERROR)

    window = _stats_window(months, year, month)
    start, end = _elapsed_window(window)

    total_days = (
        await db.scalar(
            select(func.count(func.distinct(Presence.date))).where(
                Presence.student_tax_code == tax_code,
                Presence.date >= start,
                Presence.date < end,
            ),
        )
        or 0
    )
    weeks = _weeks_of(window)

    trend_start, trend_end = _elapsed_window(_stats_window(None, None, None))
    trend_rows = (
        await db.execute(
            select(
                func.extract("year", Presence.date).label("year"),
                _month_of(Presence.date).label("month"),
                func.count(func.distinct(Presence.date)).label("presence_days"),
            )
            .where(
                Presence.student_tax_code == tax_code,
                Presence.date >= trend_start,
                Presence.date < trend_end,
            )
            .group_by(
                func.extract("year", Presence.date),
                _month_of(Presence.date),
            ),
        )
    ).all()

    return StudentPersonalStatisticsResponse(
        weekly_presence_days=round(total_days / weeks, 1) if weeks > 0 else 0.0,
        total_presence_days=total_days,
        monthly_trend=_pad_monthly(
            {
                (int(row.year), int(row.month)): row.presence_days
                for row in trend_rows
            },
        ),
        requested=await _requested_subjects(
            db,
            window,
            student_tax_code=tax_code,
            limit=_TOP_SUBJECTS_LIMIT,
        ),
    )


@router.get(
    "/course-participants/course-distribution",
    response_model=list[CourseDistributionItem],
)
async def get_course_participant_distribution(
    db: DbSession,
) -> list[CourseDistributionItem]:
    query = (
        select(
            CourseParticipant.course_type.label("label"),
            func.count(CourseParticipant.tax_code).label("participant_count"),
        )
        .group_by(CourseParticipant.course_type)
        .order_by(func.count(CourseParticipant.tax_code).desc())
    )

    result = await db.execute(query)

    return [
        CourseDistributionItem(label=course_type_label(row.label), count=row.participant_count)
        for row in result.all()
    ]