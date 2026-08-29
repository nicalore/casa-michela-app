from pydantic import BaseModel

from app.schemas.person import PersonOption


class MemberTrendItem(BaseModel):
    year: int
    month: int | None = None
    total_members: int


class RetentionRateItem(BaseModel):
    year: int
    month: int | None = None
    previous_year_members: int
    retained_members: int
    retention_rate_percentage: float


class CurrentTotalsResponse(BaseModel):
    current_total_members: int
    members_delta_month: int
    members_delta_year: int
    current_active_collaborators: int
    collab_delta_month: int
    collab_delta_year: int
    percentage_of_total_members: float | None = None
    percentage_of_total_collaborators: float | None = None


class CityDistributionItem(BaseModel):
    city: str
    count: int


class AgeDistributionItem(BaseModel):
    age_group: str
    count: int


class EducationDistributionItem(BaseModel):
    label: str
    count: int


class CertificationDistributionItem(BaseModel):
    label: str
    count: int


class SubjectDistributionItem(BaseModel):
    name: str
    program_name: str | None = None
    count: int


class AreaDistributionItem(BaseModel):
    area: str
    count: int
    percentage: float


class TeacherSubjectsStatisticsResponse(BaseModel):
    avg_subjects_per_teacher: float
    avg_teachers_per_subject: float
    top_10_subjects: list[SubjectDistributionItem]
    bottom_10_subjects: list[SubjectDistributionItem]
    area_distribution: list[AreaDistributionItem]


class CourseDistributionItem(BaseModel):
    label: str
    count: int


class TeacherAppreciationItem(BaseModel):
    teacher: PersonOption

    # Counted per teacher named, so the totals exceed the request count.
    request_count: int


class TeacherAppreciationRankingResponse(BaseModel):
    most_appreciated: list[TeacherAppreciationItem]
    least_appreciated: list[TeacherAppreciationItem]


class TeacherAvailabilityRankItem(BaseModel):
    teacher: PersonOption
    availability_count: int


class LowAvailabilityTeacherItem(BaseModel):
    teacher: PersonOption

    weekly_average: float
    availability_count: int


class TeacherAvailabilityStatisticsResponse(BaseModel):
    # Slots per week across the whole staff.
    weekly_average: float
    total_availabilities: int
    top_teachers: list[TeacherAvailabilityRankItem]
    low_availability_teachers: list[LowAvailabilityTeacherItem]

    # Under nine slots in the month; only answerable for a single-month period.
    is_single_month: bool
    low_monthly_teachers: list[LowAvailabilityTeacherItem]


class StudentPresenceRankItem(BaseModel):
    student: PersonOption
    presence_days: int


class RequestedSubjectItem(BaseModel):
    name: str
    request_count: int

    # Share of every entry of its kind in the period, not only the ten shown.
    percentage: float


class RequestedSubjectRankings(BaseModel):
    ministry_subjects: list[RequestedSubjectItem]
    disciplines: list[RequestedSubjectItem]
    services: list[RequestedSubjectItem]


class StudentPresenceStatisticsResponse(BaseModel):
    # Averaged over days with at least one presence.
    daily_average: float
    total_presence_days: int
    top_students: list[StudentPresenceRankItem]
    requested: RequestedSubjectRankings


class MonthlyCountItem(BaseModel):
    year: int
    month: int
    count: int


class TeacherPersonalStatisticsResponse(BaseModel):
    weekly_average: float
    total_availabilities: int

    # Always the last twelve months, whatever period was requested.
    monthly_trend: list[MonthlyCountItem]

    # Period average against the two-slots-a-week threshold.
    is_below_weekly_threshold: bool

    # Under nine slots in the month, answerable only about a single month.
    is_single_month: bool
    is_below_monthly_threshold: bool

    # Rank is None when the count is zero.
    preferred_count: int
    preferred_rank: int | None
    not_preferred_count: int
    not_preferred_rank: int | None


class StudentPersonalStatisticsResponse(BaseModel):
    weekly_presence_days: float
    total_presence_days: int

    # Always the last twelve months, whatever period was requested.
    monthly_trend: list[MonthlyCountItem]

    requested: RequestedSubjectRankings
