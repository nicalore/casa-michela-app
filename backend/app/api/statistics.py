from datetime import date
from typing import Annotated, Any, Final

from fastapi import APIRouter, Query
from sqlalchemy import Select, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.core.labels import education_level_label
from app.models.administrator import Administrator
from app.models.association_subject import AssociationSubject
from app.models.course_participant import CourseParticipant
from app.models.member import Member
from app.models.membership import Membership
from app.models.person import Person
from app.models.psychologist import Psychologist
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.staff import Staff
from app.models.student import Student
from app.models.study_program import StudyProgram
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence
from app.schemas.statistics import (
    AgeDistributionItem,
    AreaDistributionItem,
    CityDistributionItem,
    CourseDistributionItem,
    CurrentTotalsResponse,
    EducationDistributionItem,
    MemberTrendItem,
    RetentionRateItem,
    SubjectDistributionItem,
    TeacherSubjectsStatisticsResponse,
)

router = APIRouter(
    prefix="/statistics",
    tags=["statistics"],
)

_MONTH_RESOLUTION: Final[str] = "month"
_UNKNOWN_AREA_LABEL: Final[str] = "Altra Area"
_TOP_SUBJECTS_LIMIT: Final[int] = 10

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

    query = (
        query.order_by(Membership.year, _month_of(Membership.start_date))
        if by_month
        else query.order_by(Membership.year)
    )

    result = await db.execute(query)

    return [
        MemberTrendItem(
            year=row.year,
            month=int(row.month) if by_month and row.month else None,
            total_members=row.total,
        )
        for row in result.all()
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
        label_column = (
            StudyProgram.name if distribution_type == "program" else StudyProgram.level
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
            StudyProgram.name.label("program_name"),
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
    label_by_group: dict[str, str] = {}
    teachers_by_area: dict[str, set[str]] = {}
    teachers_by_subject: dict[int, set[str]] = {}

    for row in result.all():
        teacher_tax_code = row.teacher_tax_code
        subject_id = row.association_subject_id

        subjects_by_teacher.setdefault(teacher_tax_code, set()).add(subject_id)
        teachers_by_subject.setdefault(subject_id, set()).add(teacher_tax_code)

        if ranking_mode == "program":
            group_key = f"{subject_id}-{row.study_program_id}"
            group_label = f"{row.subject_name} - {row.program_name}"
        else:
            group_key = str(subject_id)
            group_label = row.subject_name

        teachers_by_group.setdefault(group_key, set()).add(teacher_tax_code)
        label_by_group[group_key] = group_label

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

    subject_counts = [
        SubjectDistributionItem(name=label_by_group[key], count=len(teachers))
        for key, teachers in teachers_by_group.items()
    ]

    top_subjects = sorted(
        subject_counts,
        key=lambda item: (-item.count, item.name),
    )[:_TOP_SUBJECTS_LIMIT]
    bottom_subjects = sorted(
        subject_counts,
        key=lambda item: (item.count, item.name),
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
        CourseDistributionItem(label=row.label, count=row.participant_count)
        for row in result.all()
    ]