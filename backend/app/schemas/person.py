from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


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


class ParentInfoResponse(BaseModel):
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

    # Scoped to the ParentalResponsibility row linking this parent to the
    # person the list is built for, not a property of the parent.
    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = None


class ChildInfoResponse(BaseModel):
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
    school_name: str | None = None
    school_class: str | None = None
    study_program: str | None = None

    # Scoped to the ParentalResponsibility row linking this child to the
    # parent the list is built for, not a property of the child.
    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = None


class GeneralDataUpdate(BaseModel):
    first_name: str
    last_name: str
    tax_code: str
    gender: str
    birth_date: date
    birth_city: str
    birth_nation: str
    birth_province: str
    residence_type: str
    residence_address: str
    residence_street_number: str
    residence_city: str
    residence_province: str
    postal_code: str
    email: str
    phone: str


class StaffUpdateData(BaseModel):
    collaboration_type: str
    iban: str | None = None


class AdminUpdateData(BaseModel):
    role: str
    other_role: str | None = None


class TeacherCompetenceUpdateItem(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class TeacherUpdateData(BaseModel):
    school_education: str | None = None
    university_education: str | None = None
    competences: list[TeacherCompetenceUpdateItem] | None = None
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
    certification_other_detail: str | None = None
    mandatory_psych_meetings_acknowledged: bool

    # Full history, replaced as a whole: update_person overwrites every
    # SchoolEnrollment of the student with this list, with the same semantics
    # as the dedicated school-enrollments endpoint. A partial list deletes
    # the years it omits.
    school_enrollments: list[SchoolEnrollmentUpdateItem]
    expected_updated_at: datetime | None = None


class ParentalRelationshipInput(BaseModel):
    tax_code: str
    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = None


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

    # From here on every field is optional with "absent from the JSON means
    # leave the stored value alone", not "absent means clear it": the schema
    # is shared by two callers with different scopes. The backend tells an
    # absent field from an explicit null through model_fields_set, so a plain
    # `is None` check would silently wipe data.
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
    parent_tax_code: str
    authorized_pickup: bool = True
    pickup_restriction_reason: str | None = None


class TeacherSubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    subject_id: int
    subject_name: str
    subject_area: str
    study_program_ids: list[int]
    study_programs: list[str]


class PersonTeacherCompetencesUpdate(BaseModel):
    competences: list[TeacherCompetenceUpdateItem]
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

    # Optimistic concurrency tokens for the three aggregates that have one.
    # None when the person has no such profile. Clients must send them back
    # as expected_updated_at on the matching update endpoints.
    member_updated_at: datetime | None = None
    student_updated_at: datetime | None = None
    teacher_updated_at: datetime | None = None

    memberships: list[MembershipResponse] | None = None
    school_enrollments: list[SchoolEnrollmentResponse] | None = None
    parents: list[ParentInfoResponse] | None = None
    children: list[ChildInfoResponse] | None = None
    teacher_subjects: list[TeacherSubjectResponse] | None = None