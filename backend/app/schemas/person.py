from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class MembershipResponse(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str

    model_config = ConfigDict(from_attributes=True)


class SchoolEnrollmentResponse(BaseModel):
    start_year: int
    grade: int
    school_name: str
    school_mechanographic_code: str
    study_program_name: str
    study_program_id: int
    education_level: str

    model_config = ConfigDict(from_attributes=True)


class ParentInfoResponse(BaseModel):
    fiscal_code: str
    first_name: str
    last_name: str
    gender: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    birth_city: Optional[str] = None
    birth_province: Optional[str] = None
    residence_type: Optional[str] = None
    residence_address: Optional[str] = None
    residence_street_number: Optional[str] = None
    residence_province: Optional[str] = None
    postal_code: Optional[str] = None
    city: Optional[str] = None
    birth_date: Optional[date] = None

    model_config = ConfigDict(from_attributes=True)


class ChildInfoResponse(BaseModel):
    fiscal_code: str
    first_name: str
    last_name: str
    gender: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    birth_city: Optional[str] = None
    birth_province: Optional[str] = None
    residence_type: Optional[str] = None
    residence_address: Optional[str] = None
    residence_street_number: Optional[str] = None
    residence_province: Optional[str] = None
    postal_code: Optional[str] = None
    city: Optional[str] = None
    birth_date: Optional[date] = None
    school_name: Optional[str] = None
    school_class: Optional[str] = None
    study_program: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class GeneralDataUpdate(BaseModel):
    first_name: str
    last_name: str
    tax_code: str
    gender: str
    birth_date: date
    birth_city: str
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
    iban: Optional[str] = None


class AdminUpdateData(BaseModel):
    role: str
    other_role: Optional[str] = None


class TeacherCompetenceUpdateItem(BaseModel):
    subject_id: int
    study_program_ids: List[int]


class TeacherUpdateData(BaseModel):
    school_education: Optional[str] = None
    university_education: Optional[str] = None
    competences: Optional[List[TeacherCompetenceUpdateItem]] = None


class CourseParticipantUpdateData(BaseModel):
    medical_certificate_expiration: date
    course_type: str


class StudentUpdateData(BaseModel):
    authorized_early_exit: bool
    school_mechanographic_code: str
    study_program_id: int
    school_class: str


class RelationshipsUpdate(BaseModel):
    minors_tax_codes: List[str] = []
    parents_tax_codes: List[str] = []


class PersonUpdatePayload(BaseModel):
    general_data: GeneralDataUpdate
    roles: List[str]
    staff_data: Optional[StaffUpdateData] = None
    admin_data: Optional[AdminUpdateData] = None
    teacher_data: Optional[TeacherUpdateData] = None
    course_participant_data: Optional[CourseParticipantUpdateData] = None
    student_data: Optional[StudentUpdateData] = None
    relationships: Optional[RelationshipsUpdate] = None


class MembershipUpdateItem(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class PersonMembershipsUpdate(BaseModel):
    collaborating_active: bool
    memberships: List[MembershipUpdateItem]


class RevokeMembershipPayload(BaseModel):
    revocation_type: str


class SchoolEnrollmentUpdateItem(BaseModel):
    start_year: int
    school_mechanographic_code: str
    study_program_id: int
    grade: int


class PersonSchoolEnrollmentsUpdate(BaseModel):
    enrollments: List[SchoolEnrollmentUpdateItem]


class ParentUpdatePayload(BaseModel):
    parent_tax_code: str


class TeacherSubjectResponse(BaseModel):
    subject_id: int
    subject_name: str
    subject_area: str
    study_program_ids: List[int]
    study_programs: List[str]

model_config = ConfigDict(from_attributes=True)


class PersonTeacherCompetencesUpdate(BaseModel):
    competences: List[TeacherCompetenceUpdateItem]


class PersonResponse(BaseModel):
    fiscal_code: str
    first_name: str
    last_name: str
    roles: List[str]
    created_at: datetime
    profile_image_url: Optional[str] = None
    
    gender: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    birth_city: Optional[str] = None
    birth_province: Optional[str] = None
    residence_type: Optional[str] = None
    residence_address: Optional[str] = None
    residence_street_number: Optional[str] = None
    residence_province: Optional[str] = None
    postal_code: Optional[str] = None
    
    city: Optional[str] = None
    birth_date: Optional[date] = None
    children_count: Optional[int] = None
    is_active_collaborator: Optional[bool] = None
    enrollment_year: Optional[str] = None
    education_level: Optional[str] = None
    school_name: Optional[str] = None
    school_class: Optional[str] = None
    study_program: Optional[str] = None
    early_exit: Optional[bool] = None
    collaboration_type: Optional[str] = None
    taught_subjects: List[str] = []
    course_type: Optional[str] = None
    is_medical_certificate_valid: Optional[bool] = None

    iban: Optional[str] = None
    admin_role: Optional[str] = None
    admin_other_role: Optional[str] = None
    school_education: Optional[str] = None
    university_education: Optional[str] = None
    medical_certificate_expiration: Optional[date] = None

    memberships: Optional[List[MembershipResponse]] = None
    school_enrollments: Optional[List[SchoolEnrollmentResponse]] = None
    parents: Optional[List[ParentInfoResponse]] = None
    children: Optional[List[ChildInfoResponse]] = None
    teacher_subjects: Optional[List[TeacherSubjectResponse]] = None

    model_config = ConfigDict(from_attributes=True)