from datetime import date, datetime, time
from decimal import Decimal
from typing import Annotated, Final, Self

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, model_validator

from app.core import field_lengths
from app.core.time_band import EVENING_START
from app.models.early_exit_schedule import MAXIMUM_SCHEDULES, WEEKDAYS
from app.models.student import CertificationTypeEnum, HomeworkTariffEnum
from app.models.study_program import EducationLevelEnum, HighSchoolTrackEnum
from app.models.teacher import RATING_MAXIMUM, RATING_MINIMUM, RATING_STEP
from app.schemas.validators import (
    OptionalOpeningCapitalStr,
    OptionalSentenceCaseStr,
    OptionalTitleCaseStr,
    SentenceCaseStr,
    TitleCaseStr,
    UpperCaseStr,
)

_UNIVERSITY_EDUCATION_AT_HIGH_SCHOOL_ERROR: Final[str] = (
    "Un docente che frequenta le superiori non può dichiarare studi universitari."
)

_MISSING_DSA_DETAIL_ERROR: Final[str] = (
    "Per una certificazione DSA va indicato di quale disturbo si tratta."
)

_REPEATED_CERTIFICATION_ERROR: Final[str] = (
    "Ogni certificazione può essere indicata una sola volta."
)

_RATING_STEP_ERROR: Final[str] = (
    "La valutazione di un docente si muove di mezzo punto alla volta."
)

_REPEATED_WEEKDAY_ERROR: Final[str] = (
    "Ogni giorno può essere indicato una sola volta."
)

_WEEKDAY_ON_TWO_LINES_ERROR: Final[str] = (
    "Uno stesso giorno non può comparire in due righe di uscita anticipata."
)

_LATE_EXIT_ERROR: Final[str] = (
    "L'orario di uscita deve precedere la fine delle attività "
    f"(ore {EVENING_START:%H:%M})."
)

_INCOMPLETE_EARLY_EXIT_PERIOD_ERROR: Final[str] = (
    "Per un'autorizzazione a termine servono sia la data di inizio "
    "sia quella di fine; senza date vale per tutto il periodo di iscrizione."
)

_EARLY_EXIT_PERIOD_ENDS_FIRST_ERROR: Final[str] = (
    "La fine dell'autorizzazione all'uscita anticipata non può precederne l'inizio."
)

_UNAUTHORIZED_EARLY_EXIT_PERIOD_ERROR: Final[str] = (
    "Senza autorizzazione all'uscita anticipata non si può indicare un periodo."
)

_UNAUTHORIZED_EARLY_EXIT_SCHEDULES_ERROR: Final[str] = (
    "Senza autorizzazione all'uscita anticipata non si possono indicare "
    "giorni e orari."
)


def _half_point(value: Decimal) -> Decimal:
    if value % RATING_STEP != 0:
        raise ValueError(_RATING_STEP_ERROR)

    return value


Weekday = Annotated[int, Field(ge=min(WEEKDAYS), le=max(WEEKDAYS))]


# Decimal, not float: a float like 3.4999 would pass here and fail in the DB.
TeacherRating = Annotated[
    Decimal,
    Field(ge=RATING_MINIMUM, le=RATING_MAXIMUM),
    AfterValidator(_half_point),
]


class PersonOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tax_code: str
    first_name: str
    last_name: str

    profile_image_url: str | None = None


class MembershipResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class SchoolEnrollmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    start_year: int
    grade: int
    school_id: int
    school_name: str
    school_mechanographic_code: str | None = None
    study_program_name: str
    study_program_id: int
    education_level: str


class EarlyExitScheduleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    weekdays: list[int]
    exit_time: time
    reason: str


class _RelatedPersonResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fiscal_code: str
    first_name: str
    last_name: str
    gender: str | None = None
    email: str | None = None
    phone: str | None = None
    birth_city: str | None = None
    birth_nation: str | None = None
    birth_province: str | None = None
    residence_type: str | None = None
    residence_address: str | None = None
    residence_street_number: str | None = None
    residence_province: str | None = None
    postal_code: str | None = None
    city: str | None = None
    birth_date: date | None = None

    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = None


class ParentInfoResponse(_RelatedPersonResponse):
    pass


class ChildInfoResponse(_RelatedPersonResponse):
    school_name: str | None = None
    school_class: str | None = None
    study_program: str | None = None


class GeneralDataUpdate(BaseModel):
    first_name: TitleCaseStr = Field(..., max_length=field_lengths.PERSON_NAME)
    last_name: TitleCaseStr = Field(..., max_length=field_lengths.PERSON_NAME)
    tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    gender: str
    birth_date: date
    birth_city: TitleCaseStr = Field(..., max_length=field_lengths.CITY)
    birth_nation: TitleCaseStr = Field(..., max_length=field_lengths.NATION)
    birth_province: str = Field(..., max_length=field_lengths.PROVINCE)
    residence_type: TitleCaseStr = Field(..., max_length=field_lengths.RESIDENCE_TYPE)
    residence_address: TitleCaseStr = Field(..., max_length=field_lengths.ADDRESS)
    residence_street_number: UpperCaseStr = Field(
        ...,
        max_length=field_lengths.STREET_NUMBER,
    )
    residence_city: TitleCaseStr = Field(..., max_length=field_lengths.CITY)
    residence_province: str = Field(..., max_length=field_lengths.PROVINCE)
    postal_code: str = Field(..., max_length=field_lengths.POSTAL_CODE)
    email: str = Field(..., max_length=field_lengths.EMAIL)
    phone: str = Field(..., max_length=field_lengths.PHONE)


class StaffUpdateData(BaseModel):
    collaboration_type: str
    iban: str | None = Field(None, max_length=field_lengths.IBAN)

    # Null when nobody said, which is not the same as nothing being paid.
    gross_compensation: Decimal | None = Field(None, ge=0, max_digits=10, decimal_places=2)


class AdminUpdateData(BaseModel):
    role: str
    other_role: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.OTHER_ROLE,
    )


class TeacherCompetenceUpdateItem(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class TeacherEducationData(BaseModel):
    is_high_school_student: bool
    school_education: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )
    university_education: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )

    @model_validator(mode="after")
    def _university_education_only_after_high_school(self) -> Self:
        if self.is_high_school_student and self.university_education is not None:
            raise ValueError(_UNIVERSITY_EDUCATION_AT_HIGH_SCHOOL_ERROR)

        return self


class TeacherUpdateData(TeacherEducationData):
    competences: list[TeacherCompetenceUpdateItem] | None = None

    # None means "leave unchanged": only administrators see or write the rating.
    rating: TeacherRating | None = None

    service_names: list[str] | None = None
    expected_updated_at: datetime | None = None


class CourseParticipantUpdateData(BaseModel):
    medical_certificate_expiration: date | None = None
    course_type: str


class PsychologicalSupportUpdateData(BaseModel):
    start_date: date


class SchoolEnrollmentUpdateItem(BaseModel):
    start_year: int
    school_id: int
    study_program_id: int
    grade: int


class StudentHomeworkTariffData(BaseModel):
    # Null for anyone never asked, and for primary school, which has no choice.
    homework_tariff: HomeworkTariffEnum | None = None


class StudentCertificationData(BaseModel):
    # Empty list means no certification.
    certification_types: list[str] = Field(default_factory=list)
    certification_other_detail: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    certification_dsa_detail: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.DSA_DETAIL,
    )

    @model_validator(mode="after")
    def _no_certification_is_asked_for_twice(self) -> Self:
        if len(set(self.certification_types)) != len(self.certification_types):
            raise ValueError(_REPEATED_CERTIFICATION_ERROR)

        return self

    @model_validator(mode="after")
    def _a_dsa_certification_says_which(self) -> Self:
        if (
            CertificationTypeEnum.DSA in self.certification_types
            and self.certification_dsa_detail is None
        ):
            raise ValueError(_MISSING_DSA_DETAIL_ERROR)

        return self


class EarlyExitScheduleItem(BaseModel):
    # 1=Monday .. 7=Sunday, per ISO 8601.
    weekdays: list[Weekday] = Field(..., min_length=1)
    exit_time: time
    reason: SentenceCaseStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.EARLY_EXIT_REASON,
    )

    @model_validator(mode="after")
    def _no_day_is_asked_for_twice(self) -> Self:
        if len(set(self.weekdays)) != len(self.weekdays):
            raise ValueError(_REPEATED_WEEKDAY_ERROR)

        return self

    @model_validator(mode="after")
    def _the_exit_comes_before_closing(self) -> Self:
        if self.exit_time >= EVENING_START:
            raise ValueError(_LATE_EXIT_ERROR)

        return self


class StudentEarlyExitData(BaseModel):
    authorized_early_exit: bool

    # Both absent: the authorisation lasts as long as the membership.
    early_exit_start_date: date | None = None
    early_exit_end_date: date | None = None

    early_exit_schedules: list[EarlyExitScheduleItem] = Field(
        default_factory=list,
        max_length=MAXIMUM_SCHEDULES,
    )

    @model_validator(mode="after")
    def _a_limited_period_has_both_ends(self) -> Self:
        if (self.early_exit_start_date is None) != (self.early_exit_end_date is None):
            raise ValueError(_INCOMPLETE_EARLY_EXIT_PERIOD_ERROR)

        if (
            self.early_exit_start_date is not None
            and self.early_exit_end_date is not None
            and self.early_exit_end_date < self.early_exit_start_date
        ):
            raise ValueError(_EARLY_EXIT_PERIOD_ENDS_FIRST_ERROR)

        return self

    @model_validator(mode="after")
    def _nothing_is_declared_without_the_authorization(self) -> Self:
        if self.authorized_early_exit:
            return self

        if self.early_exit_start_date is not None:
            raise ValueError(_UNAUTHORIZED_EARLY_EXIT_PERIOD_ERROR)

        if self.early_exit_schedules:
            raise ValueError(_UNAUTHORIZED_EARLY_EXIT_SCHEDULES_ERROR)

        return self

    @model_validator(mode="after")
    def _each_day_is_on_a_single_line(self) -> Self:
        seen: set[int] = set()

        for schedule in self.early_exit_schedules:
            if seen & set(schedule.weekdays):
                raise ValueError(_WEEKDAY_ON_TWO_LINES_ERROR)

            seen |= set(schedule.weekdays)

        return self


class StudentUpdateData(
    StudentCertificationData,
    StudentEarlyExitData,
    StudentHomeworkTariffData,
):
    mandatory_psych_meetings_acknowledged: bool

    school_enrollments: list[SchoolEnrollmentUpdateItem]
    expected_updated_at: datetime | None = None


class ParentalRelationshipInput(BaseModel):
    tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    authorized_pickup: bool = True
    pickup_restriction_reason: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.PICKUP_REASON,
    )


class RelationshipsUpdate(BaseModel):
    minors_tax_codes: list[ParentalRelationshipInput] = []
    parents_tax_codes: list[ParentalRelationshipInput] = []


class MembershipUpdateItem(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class PersonMembershipsUpdate(BaseModel):
    collaborating_active: bool
    memberships: list[MembershipUpdateItem]

    payment_method: str | None = None
    payment_method_other: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    statute_acknowledged: bool | None = None
    regulation_acknowledged: bool | None = None
    video_surveillance_acknowledged: bool | None = None
    special_category_data_consent: bool | None = None
    newsletter_consent: bool | None = None
    consents_signed_at: date | None = None
    emergency_contact_name: OptionalTitleCaseStr = Field(
        None,
        max_length=field_lengths.CONTACT_NAME,
    )
    emergency_contact_phone: str | None = Field(None, max_length=field_lengths.PHONE)
    allergies_notes: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.NOTES,
    )
    medications_notes: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.NOTES,
    )
    expected_updated_at: datetime | None = None


class PersonUpdatePayload(BaseModel):
    general_data: GeneralDataUpdate
    roles: list[str]
    member_data: PersonMembershipsUpdate | None = None
    staff_data: StaffUpdateData | None = None
    admin_data: AdminUpdateData | None = None
    teacher_data: TeacherUpdateData | None = None
    course_participant_data: CourseParticipantUpdateData | None = None
    psychological_support_data: PsychologicalSupportUpdateData | None = None
    student_data: StudentUpdateData | None = None
    relationships: RelationshipsUpdate | None = None


class RevokeMembershipPayload(BaseModel):
    revocation_type: str
    expected_updated_at: datetime | None = None


class PersonSchoolEnrollmentsUpdate(BaseModel):
    enrollments: list[SchoolEnrollmentUpdateItem]
    expected_updated_at: datetime | None = None


class ParentUpdatePayload(BaseModel):
    parent_tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    authorized_pickup: bool = True
    pickup_restriction_reason: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.PICKUP_REASON,
    )


class TeacherProgramResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    sector: str | None = None
    level: EducationLevelEnum

    high_school_track: HighSchoolTrackEnum | None = None


class TeacherSubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    subject_id: int
    subject_name: str
    subject_area: str
    subject_description: str | None = None
    study_programs: list[TeacherProgramResponse]


class PersonTeacherCompetencesUpdate(BaseModel):
    competences: list[TeacherCompetenceUpdateItem]
    service_names: list[str] = Field(default_factory=list)
    expected_updated_at: datetime | None = None


class PersonResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fiscal_code: str
    first_name: str
    last_name: str
    roles: list[str]
    created_at: datetime
    profile_image_url: str | None = None

    gender: str | None = None
    email: str | None = None
    phone: str | None = None
    birth_city: str | None = None
    birth_nation: str | None = None
    birth_province: str | None = None
    residence_type: str | None = None
    residence_address: str | None = None
    residence_street_number: str | None = None
    residence_province: str | None = None
    postal_code: str | None = None

    city: str | None = None
    birth_date: date | None = None
    children_count: int | None = None
    is_active_collaborator: bool | None = None
    enrollment_year: str | None = None
    education_level: str | None = None
    school_name: str | None = None
    school_class: str | None = None
    study_program: str | None = None
    early_exit: bool | None = None
    early_exit_start_date: date | None = None
    early_exit_end_date: date | None = None
    early_exit_schedules: list[EarlyExitScheduleResponse] | None = None
    collaboration_type: str | None = None
    taught_subjects: list[str] = []
    course_type: str | None = None
    is_medical_certificate_valid: bool | None = None

    certification_types: list[str] = Field(default_factory=list)
    certification_other_detail: str | None = None
    certification_dsa_detail: str | None = None
    mandatory_psych_meetings_acknowledged: bool | None = None
    homework_tariff: HomeworkTariffEnum | None = None
    gross_compensation: Decimal | None = None

    payment_method: str | None = None
    payment_method_other: str | None = None
    statute_acknowledged: bool | None = None
    regulation_acknowledged: bool | None = None
    video_surveillance_acknowledged: bool | None = None
    special_category_data_consent: bool | None = None
    newsletter_consent: bool | None = None
    consents_signed_at: date | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    allergies_notes: str | None = None
    medications_notes: str | None = None
    psychological_support_start_date: date | None = None

    iban: str | None = None
    admin_role: str | None = None
    admin_other_role: str | None = None
    is_high_school_student: bool | None = None
    school_education: str | None = None
    university_education: str | None = None
    # None for non-teachers, and never sent to non-administrator viewers.
    teacher_rating: float | None = None
    medical_certificate_expiration: date | None = None

    member_updated_at: datetime | None = None
    student_updated_at: datetime | None = None
    teacher_updated_at: datetime | None = None

    memberships: list[MembershipResponse] | None = None
    school_enrollments: list[SchoolEnrollmentResponse] | None = None
    parents: list[ParentInfoResponse] | None = None
    children: list[ChildInfoResponse] | None = None
    teacher_subjects: list[TeacherSubjectResponse] | None = None

    teacher_services: list[str] | None = None
