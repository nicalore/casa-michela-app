from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core import field_lengths
from app.models.study_program import EducationLevelEnum


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
    first_name: str = Field(..., max_length=field_lengths.PERSON_NAME)
    last_name: str = Field(..., max_length=field_lengths.PERSON_NAME)
    tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    gender: str
    birth_date: date
    birth_city: str = Field(..., max_length=field_lengths.CITY)
    birth_nation: str = Field(..., max_length=field_lengths.NATION)
    birth_province: str = Field(..., max_length=field_lengths.PROVINCE)
    residence_type: str = Field(..., max_length=field_lengths.RESIDENCE_TYPE)
    residence_address: str = Field(..., max_length=field_lengths.ADDRESS)
    residence_street_number: str = Field(..., max_length=field_lengths.STREET_NUMBER)
    residence_city: str = Field(..., max_length=field_lengths.CITY)
    residence_province: str = Field(..., max_length=field_lengths.PROVINCE)
    postal_code: str = Field(..., max_length=field_lengths.POSTAL_CODE)
    email: str = Field(..., max_length=field_lengths.EMAIL)
    phone: str = Field(..., max_length=field_lengths.PHONE)


class StaffUpdateData(BaseModel):
    collaboration_type: str
    iban: str | None = Field(None, max_length=field_lengths.IBAN)


class AdminUpdateData(BaseModel):
    role: str
    other_role: str | None = Field(None, max_length=field_lengths.OTHER_ROLE)


class TeacherCompetenceUpdateItem(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class TeacherUpdateData(BaseModel):
    school_education: str | None = Field(None, max_length=field_lengths.EDUCATION)
    university_education: str | None = Field(None, max_length=field_lengths.EDUCATION)
    competences: list[TeacherCompetenceUpdateItem] | None = None

    service_names: list[str] | None = None
    expected_updated_at: datetime | None = None


class CourseParticipantUpdateData(BaseModel):
    medical_certificate_expiration: date
    course_type: str


class PsychologicalSupportUpdateData(BaseModel):
    start_date: date


class SchoolEnrollmentUpdateItem(BaseModel):
    start_year: int
    school_id: int
    study_program_id: int
    grade: int


class StudentUpdateData(BaseModel):
    authorized_early_exit: bool
    certification_type: str | None = None
    certification_other_detail: str | None = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    mandatory_psych_meetings_acknowledged: bool

    school_enrollments: list[SchoolEnrollmentUpdateItem]
    expected_updated_at: datetime | None = None


class ParentalRelationshipInput(BaseModel):
    tax_code: str = Field(..., max_length=field_lengths.TAX_CODE)
    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = Field(
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
    payment_method_other: str | None = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    statute_acknowledged: bool | None = None
    regulation_acknowledged: bool | None = None
    video_surveillance_acknowledged: bool | None = None
    special_category_data_consent: bool | None = None
    newsletter_consent: bool | None = None
    consents_signed_at: date | None = None
    emergency_contact_name: str | None = Field(
        None,
        max_length=field_lengths.CONTACT_NAME,
    )
    emergency_contact_phone: str | None = Field(None, max_length=field_lengths.PHONE)
    allergies_notes: str | None = Field(None, max_length=field_lengths.NOTES)
    medications_notes: str | None = Field(None, max_length=field_lengths.NOTES)
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
    pickup_restriction_reason: str | None = Field(
        None,
        max_length=field_lengths.PICKUP_REASON,
    )


class TeacherProgramResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    sector: str | None = None
    level: EducationLevelEnum


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
    collaboration_type: str | None = None
    taught_subjects: list[str] = []
    course_type: str | None = None
    is_medical_certificate_valid: bool | None = None

    certification_type: str | None = None
    certification_other_detail: str | None = None
    mandatory_psych_meetings_acknowledged: bool | None = None

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
    school_education: str | None = None
    university_education: str | None = None
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
