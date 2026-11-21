from datetime import date, datetime, time
from decimal import Decimal
from typing import Annotated, Final, Literal, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.core import field_lengths
from app.core.i18n import tr
from app.core.time_band import EVENING_START
from app.models.early_exit_schedule import MAXIMUM_SCHEDULES, WEEKDAYS
from app.models.membership_revocation import ExpulsionGroundEnum
from app.models.person import BORN_ABROAD_PROVINCE
from app.models.student import CertificationTypeEnum
from app.models.study_program import EducationLevelEnum, HighSchoolTrackEnum
from app.schemas.student_note import StudentNoteResponse, TeacherNoteResponse
from app.schemas.student_payments import StudentTariffData
from app.schemas.validators import (
    OpeningCapitalStr,
    OptionalCleanStr,
    OptionalOpeningCapitalStr,
    OptionalSentenceCaseStr,
    OptionalTitleCaseStr,
    TitleCaseStr,
    UpperCaseStr,
)

UNIVERSITY_EDUCATION_AT_HIGH_SCHOOL_ERROR: Final[str] = (
    "Un docente che frequenta le superiori non può dichiarare studi universitari."
)

HEALTH_DATA_WITHOUT_CONSENT_ERROR: Final[str] = (
    "Senza il consenso ai dati particolari non si possono registrare allergie, "
    "farmaci, certificazioni e sostegno psicologico."
)


def university_education_at_high_school_error() -> str:
    return tr(
        UNIVERSITY_EDUCATION_AT_HIGH_SCHOOL_ERROR,
        "A teacher still at upper secondary school can't list university studies.",
    )


def health_data_without_consent_error() -> str:
    return tr(
        HEALTH_DATA_WITHOUT_CONSENT_ERROR,
        "Without consent to special category data, allergies, medications, "
        "certifications and psychological support can't be recorded.",
    )

_MISSING_DSA_DETAIL_ERROR: Final[tuple[str, str]] = (
    "Per una certificazione DSA va indicato di quale disturbo si tratta.",
    "For an SLD (specific learning disorder) certification, say which disorder it is.",
)

_MISSING_BIRTH_CITY_ERROR: Final[tuple[str, str]] = (
    "Per chi è nato in Italia va indicata la città di nascita.",
    "For people born in Italy, the city of birth is required.",
)

_REPEATED_CERTIFICATION_ERROR: Final[tuple[str, str]] = (
    "Ogni certificazione può essere indicata una sola volta.",
    "Each certification can be given only once.",
)

_REPEATED_WEEKDAY_ERROR: Final[tuple[str, str]] = (
    "Ogni giorno può essere indicato una sola volta.",
    "Each day can be given only once.",
)

_WEEKDAY_ON_TWO_LINES_ERROR: Final[tuple[str, str]] = (
    "Uno stesso giorno non può comparire in due righe di uscita anticipata.",
    "The same day can't appear in two early departure rows.",
)

_SCHOOL_OR_HOMESCHOOLING_ERROR: Final[tuple[str, str]] = (
    "Per ogni anno scolastico indica la scuola oppure l'istruzione parentale.",
    "For each school year give the school or home education.",
)

_LATE_EXIT_ERROR: Final[tuple[str, str]] = (
    "L'orario di uscita deve precedere la fine delle attività "
    f"(ore {EVENING_START:%H:%M}).",
    f"The leaving time must come before activities end ({EVENING_START:%H:%M}).",
)

_INCOMPLETE_EARLY_EXIT_PERIOD_ERROR: Final[tuple[str, str]] = (
    "Per un'autorizzazione a termine servono sia la data di inizio sia quella di "
    "fine; senza date vale per tutto il periodo di iscrizione.",
    "A time-limited authorisation needs both a start and an end date; without dates "
    "it covers the whole enrolment period.",
)

_EARLY_EXIT_PERIOD_ENDS_FIRST_ERROR: Final[tuple[str, str]] = (
    "La fine dell'autorizzazione all'uscita anticipata non può precederne l'inizio.",
    "The early departure authorisation can't end before it starts.",
)

_UNAUTHORIZED_EARLY_EXIT_PERIOD_ERROR: Final[tuple[str, str]] = (
    "Senza autorizzazione all'uscita anticipata non si può indicare un periodo.",
    "Without early departure authorisation no period can be given.",
)

_UNAUTHORIZED_EARLY_EXIT_SCHEDULES_ERROR: Final[tuple[str, str]] = (
    "Senza autorizzazione all'uscita anticipata non si possono indicare giorni e "
    "orari.",
    "Without early departure authorisation no days and times can be given.",
)


Weekday = Annotated[int, Field(ge=min(WEEKDAYS), le=max(WEEKDAYS))]


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

    # Administrators only: money holds the year, and its start no later than this.
    locked: bool = False
    latest_start: date | None = None


class SchoolEnrollmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    start_year: int
    grade: int

    # Null under homeschooling, whose label then stands in for the name.
    school_id: int | None = None
    homeschooling: bool = False
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
    profile_image_url: str | None = None
    roles: list[str] = []

    # None for readers who are not administrators.
    authorized_pickup: bool | None = True
    pickup_restriction_reason: str | None = None


class ParentInfoResponse(_RelatedPersonResponse):
    has_account: bool = False


class ChildInfoResponse(_RelatedPersonResponse):
    school_name: str | None = None
    school_class: str | None = None
    study_program: str | None = None
    course_type: str | None = None
    medical_certificate_expiration: date | None = None


# Shared by every road into the register: the wizard and the person form.
class BirthPlaceData(BaseModel):
    # Absent only for a birthplace abroad, where the registry may not know it.
    birth_city: OptionalTitleCaseStr = Field(None, max_length=field_lengths.CITY)
    birth_nation: TitleCaseStr = Field(..., max_length=field_lengths.NATION)
    birth_province: str = Field(..., max_length=field_lengths.PROVINCE)

    @model_validator(mode="after")
    def _the_city_is_known_unless_born_abroad(self) -> Self:
        if self.birth_city is None and self.birth_province != BORN_ABROAD_PROVINCE:
            raise ValueError(tr(*_MISSING_BIRTH_CITY_ERROR))

        return self


class GeneralDataUpdate(BirthPlaceData):
    first_name: TitleCaseStr = Field(..., max_length=field_lengths.PERSON_NAME)
    last_name: TitleCaseStr = Field(..., max_length=field_lengths.PERSON_NAME)
    tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    gender: str
    birth_date: date
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
    # Null keeps it, rate included: they change in the Compensi tab.
    collaboration_type: str | None = None
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
    school_education: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )
    university_education: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )

    @model_validator(mode="after")
    def _university_education_only_after_high_school(self) -> Self:
        if self.is_high_school_student and self.university_education is not None:
            raise ValueError(university_education_at_high_school_error())

        return self


# A teacher's own studies; the still-at-school flag is the register's, not theirs.
class OwnEducationData(BaseModel):
    school_education: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )
    university_education: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.EDUCATION,
    )


class TeacherUpdateData(TeacherEducationData):
    competences: list[TeacherCompetenceUpdateItem] | None = None

    service_names: list[str] | None = None
    expected_updated_at: datetime | None = None


class CourseParticipantUpdateData(BaseModel):
    medical_certificate_expiration: date | None = None
    course_type: str


class PsychologicalSupportUpdateData(BaseModel):
    start_date: date


# Exactly one of the two: homeschooling has no school.
class SchoolOrHomeschooling(BaseModel):
    school_id: int | None = None
    homeschooling: bool = False

    @model_validator(mode="after")
    def _school_or_homeschooling(self) -> Self:
        if self.homeschooling == (self.school_id is not None):
            raise ValueError(tr(*_SCHOOL_OR_HOMESCHOOLING_ERROR))

        return self


class SchoolEnrollmentUpdateItem(SchoolOrHomeschooling):
    start_year: int
    study_program_id: int
    grade: int


class StudentTariffChoice(BaseModel):
    # Null when no school year says the level yet.
    tariff: StudentTariffData | None = None


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
            raise ValueError(tr(*_REPEATED_CERTIFICATION_ERROR))

        return self

    @model_validator(mode="after")
    def _a_dsa_certification_says_which(self) -> Self:
        if (
            CertificationTypeEnum.DSA in self.certification_types
            and self.certification_dsa_detail is None
        ):
            raise ValueError(tr(*_MISSING_DSA_DETAIL_ERROR))

        return self


class StudentCertificationsUpdate(StudentCertificationData):
    certification_types: list[CertificationTypeEnum] = Field(default_factory=list)


class EarlyExitScheduleItem(BaseModel):
    # 1=Monday .. 7=Sunday, as date.isoweekday().
    weekdays: list[Weekday] = Field(..., min_length=1)
    exit_time: time
    reason: OpeningCapitalStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.EARLY_EXIT_REASON,
    )

    @model_validator(mode="after")
    def _no_day_is_asked_for_twice(self) -> Self:
        if len(set(self.weekdays)) != len(self.weekdays):
            raise ValueError(tr(*_REPEATED_WEEKDAY_ERROR))

        return self

    @model_validator(mode="after")
    def _the_exit_comes_before_closing(self) -> Self:
        if self.exit_time >= EVENING_START:
            raise ValueError(tr(*_LATE_EXIT_ERROR))

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
            raise ValueError(tr(*_INCOMPLETE_EARLY_EXIT_PERIOD_ERROR))

        if (
            self.early_exit_start_date is not None
            and self.early_exit_end_date is not None
            and self.early_exit_end_date < self.early_exit_start_date
        ):
            raise ValueError(tr(*_EARLY_EXIT_PERIOD_ENDS_FIRST_ERROR))

        return self

    @model_validator(mode="after")
    def _nothing_is_declared_without_the_authorization(self) -> Self:
        if self.authorized_early_exit:
            return self

        if self.early_exit_start_date is not None:
            raise ValueError(tr(*_UNAUTHORIZED_EARLY_EXIT_PERIOD_ERROR))

        if self.early_exit_schedules:
            raise ValueError(tr(*_UNAUTHORIZED_EARLY_EXIT_SCHEDULES_ERROR))

        return self

    @model_validator(mode="after")
    def _each_day_is_on_a_single_line(self) -> Self:
        seen: set[int] = set()

        for schedule in self.early_exit_schedules:
            if seen & set(schedule.weekdays):
                raise ValueError(tr(*_WEEKDAY_ON_TWO_LINES_ERROR))

            seen |= set(schedule.weekdays)

        return self


# No certifications: they have their own route. The tariff only for a new pupil.
class StudentUpdateData(StudentEarlyExitData, StudentTariffChoice):
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


# No revocation: revoke-membership alone writes one.
class MembershipUpdateItem(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int


class PersonMembershipsUpdate(BaseModel):
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
    founder: bool | None = None
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


# True once the admin agreed to what the save deletes (write_losses.Losses).
class PersonMembershipsEdit(PersonMembershipsUpdate):
    confirm: bool = False


class PersonUpdatePayload(BaseModel):
    # As in PersonMembershipsEdit: enrollment and roles taken away alike.
    confirm: bool = False
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
    revocation_type: Literal["RESIGNATION", "EXPULSION"]
    expected_updated_at: datetime | None = None

    # What the cessation form prints; the expulsion fields only for an expulsion.
    reason: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.REVOCATION_REASON,
    )
    resolution_date: date | None = None
    minutes_number: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.REVOCATION_MINUTES,
    )
    grounds: list[ExpulsionGroundEnum] = Field(default_factory=list)
    other_ground: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.REVOCATION_OTHER_GROUND,
    )
    charged_on: date | None = None
    protocol_number: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.REVOCATION_PROTOCOL,
    )
    card_number: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.REVOCATION_CARD,
    )
    guardian_tax_code: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.TAX_CODE,
    )


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

    # The span names an OTHER track, so the client needs it to build the name.
    min_year: int
    max_year: int


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


# The whole list the pupil holds today; uncapped, it is an opinion not a pick.
class PersonNotPreferredTeachersUpdate(BaseModel):
    teacher_tax_codes: list[str] = Field(default_factory=list)
    expected_updated_at: datetime | None = None

    @field_validator("teacher_tax_codes", mode="before")
    @classmethod
    def _drop_duplicate_tax_codes(cls, value: object) -> object:
        if isinstance(value, list):
            return list(dict.fromkeys(value))

        return value


class PersonResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fiscal_code: str
    first_name: str
    last_name: str
    roles: list[str] = []
    created_at: datetime
    profile_image_url: str | None = None
    has_account: bool = False
    # No enrollment stands behind an account: none may be opened, or used.
    access_lapsed: bool = False

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
    # Sent in its place to readers outside the household.
    age: int | None = None
    birthday_today: bool | None = None
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
    gross_compensation: Decimal | None = None

    payment_method: str | None = None
    payment_method_other: str | None = None
    statute_acknowledged: bool | None = None
    regulation_acknowledged: bool | None = None
    video_surveillance_acknowledged: bool | None = None
    special_category_data_consent: bool | None = None
    newsletter_consent: bool | None = None
    founder: bool | None = None
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
    teacher_criteria: list[str] | None = None
    medical_certificate_expiration: date | None = None

    member_updated_at: datetime | None = None
    student_updated_at: datetime | None = None
    teacher_updated_at: datetime | None = None

    memberships: list[MembershipResponse] | None = None

    # Administrators only: roles the edit wizard cannot take away (role_removal).
    kept_roles: list[str] | None = None
    keeps_staff: bool | None = None

    school_enrollments: list[SchoolEnrollmentResponse] | None = None
    parents: list[ParentInfoResponse] | None = None
    children: list[ChildInfoResponse] | None = None
    teacher_children_tax_codes: list[str] = []
    teacher_subjects: list[TeacherSubjectResponse] | None = None

    teacher_services: list[str] | None = None

    # None for non-students; a pupil with nothing to say gets an empty list.
    not_preferred_teachers: list[PersonOption] | None = None

    # None for non-students, newest first.
    methodological_notes: list[StudentNoteResponse] | None = None
    technical_notes: list[StudentNoteResponse] | None = None
    # Administrators only.
    teacher_notes: list[TeacherNoteResponse] | None = None
    administrator_notes: list[StudentNoteResponse] | None = None
