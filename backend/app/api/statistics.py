from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
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

def _get_role_filter(role: str | None, select_stmt):
    if not role:
        return select_stmt
    
    if role == "administrator":
        return select_stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Administrator, Staff.tax_code == Administrator.tax_code
        )
    elif role == "psychologist":
        return select_stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Psychologist, Staff.tax_code == Psychologist.tax_code
        )
    elif role == "teacher":
        return select_stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Teacher, Staff.tax_code == Teacher.tax_code
        )
    elif role == "student":
        return select_stmt.join(
            Student, Member.tax_code == Student.tax_code
        )
    elif role == "course_participant":
        return select_stmt.join(
            CourseParticipant, Member.tax_code == CourseParticipant.tax_code
        )
    
    return select_stmt


def _get_person_role_filter(role: str, select_stmt):
    stmt = select_stmt.join(
        Member, Person.tax_code == Member.tax_code
    )
    if role == "administrator":
        return stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Administrator, Staff.tax_code == Administrator.tax_code
        )
    elif role == "psychologist":
        return stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Psychologist, Staff.tax_code == Psychologist.tax_code
        )
    elif role == "teacher":
        return stmt.join(
            Staff, Member.tax_code == Staff.tax_code
        ).join(
            Teacher, Staff.tax_code == Teacher.tax_code
        )
    elif role == "student":
        return stmt.join(
            Student, Member.tax_code == Student.tax_code
        )
    elif role == "course_participant":
        return stmt.join(
            CourseParticipant, Member.tax_code == CourseParticipant.tax_code
        )
    return stmt


async def _calculate_current_totals_dashboard(role: str | None, db: AsyncSession) -> CurrentTotalsResponse:
    today   = date.today()
    c_year  = today.year
    c_month = today.month

    m_curr_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        Membership.year == c_year
    )
    m_curr_q = _get_role_filter(role, m_curr_q)
    m_curr   = await db.scalar(m_curr_q) or 0

    c_curr_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(Membership.year == c_year, Member.collaborating_active == True)
    )
    c_curr_q = _get_role_filter(role, c_curr_q)
    c_curr   = await db.scalar(c_curr_q) or 0

    m_start_m_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(Membership.year == c_year, func.extract('month', Membership.start_date) < c_month)
    )
    m_start_m_q = _get_role_filter(role, m_start_m_q)
    m_start_m   = await db.scalar(m_start_m_q) or 0

    c_start_m_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(Membership.year == c_year, func.extract('month', Membership.start_date) < c_month, Member.collaborating_active == True)
    )
    c_start_m_q = _get_role_filter(role, c_start_m_q)
    c_start_m   = await db.scalar(c_start_m_q) or 0

    m_start_y_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        Membership.year == c_year - 1
    )
    m_start_y_q = _get_role_filter(role, m_start_y_q)
    m_start_y   = await db.scalar(m_start_y_q) or 0

    c_start_y_q = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(Membership.year == c_year - 1, Member.collaborating_active == True)
    )
    c_start_y_q = _get_role_filter(role, c_start_y_q)
    c_start_y   = await db.scalar(c_start_y_q) or 0

    percentage_members = None
    percentage_collab  = None

    if role is not None:
        gen_m_curr_q = select(
            func.count(Membership.member_tax_code)
        ).join(
            Member
        ).where(
            Membership.year == c_year
        )
        gen_m_curr = await db.scalar(gen_m_curr_q) or 0

        gen_c_curr_q = select(
            func.count(Membership.member_tax_code)
        ).join(
            Member
        ).where(
            and_(Membership.year == c_year, Member.collaborating_active == True)
        )
        gen_c_curr = await db.scalar(gen_c_curr_q) or 0

        percentage_members = round((m_curr / gen_m_curr * 100), 1) if gen_m_curr > 0 else 0.0
        percentage_collab  = round((c_curr / gen_c_curr * 100), 1) if gen_c_curr > 0 else 0.0

    return CurrentTotalsResponse(
        current_total_members=m_curr,
        members_delta_month=m_curr - m_start_m,
        members_delta_year=m_curr - m_start_y,
        current_active_collaborators=c_curr,
        collab_delta_month=c_curr - c_start_m,
        collab_delta_year=c_curr - c_start_y,
        percentage_of_total_members=percentage_members,
        percentage_of_total_collaborators=percentage_collab
    )


async def _execute_members_trend(role: str | None, resolution: str, start_year: int | None, end_year: int | None, db: AsyncSession):
    if resolution == "month":
        query = select(
            Membership.year, 
            func.extract('month', Membership.start_date).label('month'), 
            func.count(Membership.member_tax_code).label("total")
        ).join(
            Member
        ).group_by(
            Membership.year, func.extract('month', Membership.start_date)
        )
    else:
        query = select(
            Membership.year, 
            func.count(Membership.member_tax_code).label("total")
        ).join(
            Member
        ).group_by(
            Membership.year
        )
    
    query = _get_role_filter(role, query)
    
    if start_year is not None:
        query = query.where(Membership.year >= start_year)
    if end_year is not None:
        query = query.where(Membership.year <= end_year)
        
    query = query.order_by(Membership.year, func.extract('month', Membership.start_date)) if resolution == "month" else query.order_by(Membership.year)
    result = await db.execute(query)
    
    return [
        MemberTrendItem(
            year=r.year, 
            month=int(r.month) if resolution == "month" and r.month else None, 
            total_members=r.total
        ) 
        for r in result.all()
    ]


async def _execute_collaborating_trend(role: str | None, resolution: str, start_year: int | None, end_year: int | None, db: AsyncSession):
    if resolution == "month":
        query = select(
            Membership.year, 
            func.extract('month', Membership.start_date).label('month'), 
            func.count(Membership.member_tax_code).label("total")
        ).join(
            Member
        ).where(
            Member.collaborating_active == True
        ).group_by(
            Membership.year, func.extract('month', Membership.start_date)
        )
    else:
        query = select(
            Membership.year, 
            func.count(Membership.member_tax_code).label("total")
        ).join(
            Member
        ).where(
            Member.collaborating_active == True
        ).group_by(
            Membership.year
        )
        
    query = _get_role_filter(role, query)
    
    if start_year is not None:
        query = query.where(Membership.year >= start_year)
    if end_year is not None:
        query = query.where(Membership.year <= end_year)
        
    query = query.order_by(Membership.year, func.extract('month', Membership.start_date)) if resolution == "month" else query.order_by(Membership.year)
    result = await db.execute(query)
    
    return [
        MemberTrendItem(
            year=r.year, 
            month=int(r.month) if resolution == "month" and r.month else None, 
            total_members=r.total
        ) 
        for r in result.all()
    ]


async def _execute_retention_rate(role: str | None, year: int, db: AsyncSession) -> RetentionRateItem:
    subq_prev_stmt = select(
        Membership.member_tax_code
    ).join(
        Member
    ).where(
        Membership.year == year - 1
    )
    subq_prev_stmt = _get_role_filter(role, subq_prev_stmt)
    subq_prev      = subq_prev_stmt.subquery()
    
    prev_count_query = select(func.count(subq_prev.c.member_tax_code))
    prev_count_raw   = await db.scalar(prev_count_query)
    prev_count: int  = int(prev_count_raw) if prev_count_raw is not None else 0
    
    if prev_count == 0:
        return RetentionRateItem(
            year=year, 
            previous_year_members=0, 
            retained_members=0, 
            retention_rate_percentage=0.0
        )
        
    retained_query = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(Membership.year == year, Membership.member_tax_code.in_(select(subq_prev.c.member_tax_code)))
    )
    retained_query = _get_role_filter(role, retained_query)
    
    retained_count_raw  = await db.scalar(retained_query)
    retained_count: int = int(retained_count_raw) if retained_count_raw is not None else 0
    
    return RetentionRateItem(
        year=year, 
        previous_year_members=prev_count, 
        retained_members=retained_count, 
        retention_rate_percentage=round((retained_count / prev_count) * 100.0, 2)
    )


async def _execute_collaborating_retention(role: str | None, year: int, month: int, db: AsyncSession) -> RetentionRateItem:
    prev_m = 12 if month == 1 else month - 1
    prev_y = year - 1 if month == 1 else year
    
    subq_prev_stmt = select(
        Membership.member_tax_code
    ).join(
        Member
    ).where(
        and_(Membership.year == prev_y, func.extract('month', Membership.start_date) <= prev_m, Member.collaborating_active == True)
    )
    subq_prev_stmt = _get_role_filter(role, subq_prev_stmt)
    subq_prev      = subq_prev_stmt.subquery()
    
    prev_count_query = select(func.count(subq_prev.c.member_tax_code))
    prev_count_raw   = await db.scalar(prev_count_query)
    prev_count: int  = int(prev_count_raw) if prev_count_raw is not None else 0
    
    if prev_count == 0:
        return RetentionRateItem(
            year=year, 
            month=month, 
            previous_year_members=0, 
            retained_members=0, 
            retention_rate_percentage=0.0
        )
        
    retained_query = select(
        func.count(Membership.member_tax_code)
    ).join(
        Member
    ).where(
        and_(
            Membership.year == year, 
            func.extract('month', Membership.start_date) <= month, 
            Member.collaborating_active == True, 
            Membership.member_tax_code.in_(select(subq_prev.c.member_tax_code))
        )
    )
    retained_query = _get_role_filter(role, retained_query)
    
    retained_count_raw  = await db.scalar(retained_query)
    retained_count: int = int(retained_count_raw) if retained_count_raw is not None else 0
    
    return RetentionRateItem(
        year=year, 
        month=month, 
        previous_year_members=prev_count, 
        retained_members=retained_count, 
        retention_rate_percentage=round((retained_count / prev_count) * 100.0, 2)
    )


@router.get("/general/current-totals", response_model=CurrentTotalsResponse)
async def get_general_current_totals(db: AsyncSession = Depends(get_db)):
    return await _calculate_current_totals_dashboard(None, db)


@router.get("/general/members-trend", response_model=list[MemberTrendItem])
async def get_general_members_trend(
    resolution: str = Query("year"), 
    start_year: int | None = Query(None), 
    end_year: int | None = Query(None), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_members_trend(None, resolution, start_year, end_year, db)


@router.get("/general/collaborating-trend", response_model=list[MemberTrendItem])
async def get_general_collaborating_trend(
    resolution: str = Query("year"), 
    start_year: int | None = Query(None), 
    end_year: int | None = Query(None), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_collaborating_trend(None, resolution, start_year, end_year, db)


@router.get("/general/retention-rate", response_model=RetentionRateItem)
async def get_general_retention_rate(
    year: int = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_retention_rate(None, year, db)


@router.get("/general/collaborating-retention", response_model=RetentionRateItem)
async def get_general_collaborating_retention(
    year: int = Query(...), 
    month: int = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_collaborating_retention(None, year, month, db)


@router.get("/role/current-totals", response_model=CurrentTotalsResponse)
async def get_role_current_totals(
    role: str = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    return await _calculate_current_totals_dashboard(role, db)


@router.get("/role/members-trend", response_model=list[MemberTrendItem])
async def get_role_members_trend(
    role: str = Query(...), 
    resolution: str = Query("year"), 
    start_year: int | None = Query(None), 
    end_year: int | None = Query(None), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_members_trend(role, resolution, start_year, end_year, db)


@router.get("/role/collaborating-trend", response_model=list[MemberTrendItem])
async def get_role_collaborating_trend(
    role: str = Query(...), 
    resolution: str = Query("year"), 
    start_year: int | None = Query(None), 
    end_year: int | None = Query(None), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_collaborating_trend(role, resolution, start_year, end_year, db)


@router.get("/role/retention-rate", response_model=RetentionRateItem)
async def get_role_retention_rate(
    role: str = Query(...), 
    year: int = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_retention_rate(role, year, db)


@router.get("/role/collaborating-retention", response_model=RetentionRateItem)
async def get_role_collaborating_retention(
    role: str = Query(...), 
    year: int = Query(...), 
    month: int = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    return await _execute_collaborating_retention(role, year, month, db)


@router.get("/role/city-distribution", response_model=list[CityDistributionItem])
async def get_role_city_distribution(
    role: str = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    query = select(
        Person.residence_city.label("city"), 
        func.count(Person.tax_code).label("member_count")
    ).group_by(
        Person.residence_city
    )
    query  = _get_person_role_filter(role, query)
    query  = query.order_by(func.count(Person.tax_code).desc())
    
    result = await db.execute(query)
    
    return [
        CityDistributionItem(
            city=r.city, 
            count=r.member_count
        ) 
        for r in result.all()
    ]


@router.get("/role/age-distribution", response_model=list[AgeDistributionItem])
async def get_role_age_distribution(
    role: str = Query(...), 
    db: AsyncSession = Depends(get_db)
):
    query  = select(Person.birth_date)
    query  = _get_person_role_filter(role, query)
    
    result = await db.execute(query)
    dates  = result.scalars().all()
    
    buckets = {
        "< 11": 0, 
        "11-14": 0, 
        "15-18": 0, 
        "19-25": 0, 
        "26-35": 0, 
        "36-50": 0, 
        "> 50": 0
    }
    today = date.today()
    
    for bd in dates:
        age = today.year - bd.year - ((today.month, today.day) < (bd.month, bd.day))
        
        if age < 11:
            buckets["< 11"] += 1
        elif age <= 14:
            buckets["11-14"] += 1
        elif age <= 18:
            buckets["15-18"] += 1
        elif age <= 25:
            buckets["19-25"] += 1
        elif age <= 35:
            buckets["26-35"] += 1
        elif age <= 50:
            buckets["36-50"] += 1
        else:
            buckets["> 50"] += 1
            
    return [
        AgeDistributionItem(
            age_group=k, 
            count=v
        ) 
        for k, v in buckets.items() if v > 0
    ]


@router.get("/students/education-distribution", response_model=list[EducationDistributionItem])
async def get_student_education_distribution(
    distribution_type: str = Query("school"),
    db: AsyncSession = Depends(get_db)
):
    query = select(
        func.count(func.distinct(Student.tax_code)).label("student_count")
    )
    query = query.join(
        SchoolEnrollment, Student.tax_code == SchoolEnrollment.student_tax_code
    )
    
    if distribution_type == "school":
        query = query.join(
            SchoolStudyProgram, 
            and_(SchoolEnrollment.study_program_id == SchoolStudyProgram.study_program_id, SchoolEnrollment.school_mechanographic_code == SchoolStudyProgram.school_mechanographic_code)
        ).join(
            School, SchoolStudyProgram.school_mechanographic_code == School.mechanographic_code
        )
        query = query.add_columns(School.name.label("label")).group_by(School.name)
        
    elif distribution_type == "program":
        query = query.join(
            SchoolStudyProgram, 
            and_(SchoolEnrollment.study_program_id == SchoolStudyProgram.study_program_id, SchoolEnrollment.school_mechanographic_code == SchoolStudyProgram.school_mechanographic_code)
        ).join(
            StudyProgram, SchoolStudyProgram.study_program_id == StudyProgram.id
        )
        query = query.add_columns(StudyProgram.name.label("label")).group_by(StudyProgram.name)
        
    elif distribution_type == "level":
        query = query.join(
            SchoolStudyProgram, 
            and_(SchoolEnrollment.study_program_id == SchoolStudyProgram.study_program_id, SchoolEnrollment.school_mechanographic_code == SchoolStudyProgram.school_mechanographic_code)
        ).join(
            StudyProgram, SchoolStudyProgram.study_program_id == StudyProgram.id
        )
        query = query.add_columns(StudyProgram.level.label("label")).group_by(StudyProgram.level)

    query  = query.order_by(func.count(func.distinct(Student.tax_code)).desc())
    result = await db.execute(query)

    def _format_level(val: str) -> str:
        if val == "PRIMARY_SCHOOL": 
            return "Scuola primaria"
        if val == "MIDDLE_SCHOOL": 
            return "Scuola secondaria di I grado"
        if val == "HIGH_SCHOOL": 
            return "Scuola secondaria di II grado"
        return val

    items = []
    
    for r in result.all():
        lbl = _format_level(r.label) if distribution_type == "level" else r.label
        items.append(
            EducationDistributionItem(
                label=lbl, 
                count=r.student_count
            )
        )

    return items


@router.get("/teachers/subjects-statistics", response_model=TeacherSubjectsStatisticsResponse)
async def get_teacher_subjects_statistics(
    ranking_mode: str = Query("absolute"), 
    db: AsyncSession = Depends(get_db)
):
    #Comment:Isolate active teachers
    active_teachers_subq = select(
        Teacher.tax_code
    ).join(
        Staff
    ).join(
        Member
    ).where(
        Member.collaborating_active == True
    ).subquery()
    
    #Comment:Join competences with subjects exclusively for active teachers
    comp_query = select(
        TeachingCompetence.teacher_tax_code,
        TeachingCompetence.association_subject_id,
        TeachingCompetence.study_program_id,
        AssociationSubject.name.label("subject_name"),
        AssociationSubject.area,
        StudyProgram.name.label("program_name")
    ).join(
        AssociationSubject, TeachingCompetence.association_subject_id == AssociationSubject.id
    ).join(
        StudyProgram, TeachingCompetence.study_program_id == StudyProgram.id
    ).where(
        TeachingCompetence.teacher_tax_code.in_(select(active_teachers_subq))
    )
     
    result = await db.execute(comp_query)
    rows   = result.all()
    
    teacher_subjects     = {} 
    subject_teachers     = {} 
    subject_names        = {}
    area_teachers        = {}
    abs_subject_teachers = {}
    
    for r in rows:
        t_code = r.teacher_tax_code
        s_id   = r.association_subject_id
        p_id   = r.study_program_id
        s_name = r.subject_name
        p_name = r.program_name
        s_area = getattr(r.area, 'value', str(r.area)) if hasattr(r.area, 'value') else (str(r.area) if r.area else "Altra Area")
        
        teacher_subjects.setdefault(t_code, set()).add(s_id)
        abs_subject_teachers.setdefault(s_id, set()).add(t_code)
        
        if ranking_mode == "program":
            group_key   = f"{s_id}-{p_id}"
            group_label = f"{s_name} - {p_name}"
        else:
            group_key   = str(s_id)
            group_label = s_name
            
        subject_teachers.setdefault(group_key, set()).add(t_code)
        subject_names[group_key] = group_label
        
        area_teachers.setdefault(s_area, set()).add(t_code)
        
    total_teachers          = len(teacher_subjects)
    total_absolute_subjects = len(abs_subject_teachers)
    
    avg_subj_per_teacher = sum(len(s) for s in teacher_subjects.values()) / total_teachers if total_teachers > 0 else 0.0
    avg_teach_per_subj   = sum(len(t) for t in abs_subject_teachers.values()) / total_absolute_subjects if total_absolute_subjects > 0 else 0.0
    
    subj_counts = [
        {
            "name": subject_names[k], 
            "count": len(t_set)
        } 
        for k, t_set in subject_teachers.items()
    ]
    
    subj_counts.sort(key=lambda x: (-x["count"], x["name"]))
    
    top_10    = subj_counts[:10]
    bottom_10 = sorted(subj_counts, key=lambda x: (x["count"], x["name"]))[:10]
    
    area_dist = []
    
    for area, t_set in area_teachers.items():
        count = len(t_set)
        perc  = (count / total_teachers * 100) if total_teachers > 0 else 0.0
        
        area_dist.append(
            AreaDistributionItem(
                area=area, 
                count=count, 
                percentage=round(perc, 1)
            )
        )
        
    area_dist.sort(key=lambda x: x.count, reverse=True)
    
    return TeacherSubjectsStatisticsResponse(
        avg_subjects_per_teacher=round(avg_subj_per_teacher, 1),
        avg_teachers_per_subject=round(avg_teach_per_subj, 1),
        top_10_subjects=[SubjectDistributionItem(**x) for x in top_10],
        bottom_10_subjects=[SubjectDistributionItem(**x) for x in bottom_10],
        area_distribution=area_dist
    )


@router.get("/course-participants/course-distribution", response_model=list[CourseDistributionItem])
async def get_course_participant_distribution(db: AsyncSession = Depends(get_db)):
    query = select(
        CourseParticipant.course_type.label("label"), 
        func.count(CourseParticipant.tax_code).label("participant_count")
    ).group_by(
        CourseParticipant.course_type
    ).order_by(
        func.count(CourseParticipant.tax_code).desc()
    )
    
    result = await db.execute(query)
    
    return [
        CourseDistributionItem(
            label=r.label, 
            count=r.participant_count
        ) 
        for r in result.all()
    ]