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

    # A request may name three teachers per side, so a period's counts sum
    # to more than its requests.
    request_count: int


class TeacherAppreciationRankingResponse(BaseModel):
    most_appreciated: list[TeacherAppreciationItem]
    least_appreciated: list[TeacherAppreciationItem]
