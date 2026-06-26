from datetime import date
from typing import List, Optional

from pydantic import BaseModel, Field


class WizardGeneralData(BaseModel):
    first_name:              str  = Field(..., min_length=1)
    last_name:               str  = Field(..., min_length=1)
    tax_code:                str  = Field(..., min_length=16, max_length=16)
    gender:                  str
    birth_date:              date
    birth_city:              str
    birth_province:          str  = Field(..., max_length=2)
    residence_type:          str
    residence_address:       str
    residence_street_number: str
    residence_city:          str
    residence_province:      str  = Field(..., max_length=2)
    postal_code:             str  = Field(..., max_length=5)
    email:                   str  
    phone:                   str


class WizardMembershipData(BaseModel):
    year:                int
    start_date:          date
    end_date:            date
    renewal_period_days: int
    revocation:          str


class WizardMemberData(BaseModel):
    memberships: List[WizardMembershipData] = Field(default_factory=list)


class WizardStaffData(BaseModel):
    collaboration_type: str
    iban:               Optional[str] = None


class WizardAdminData(BaseModel):
    role:       str
    other_role: Optional[str] = None


class WizardTeachingCompetence(BaseModel):
    subject_id:        int
    study_program_ids: List[int]


class WizardTeacherData(BaseModel):
    school_education:     Optional[str] = None
    university_education: Optional[str] = None
    competences:          List[WizardTeachingCompetence] = Field(default_factory=list)


class WizardCourseParticipantData(BaseModel):
    medical_certificate_expiration: date
    course_type:                    str


class WizardStudentData(BaseModel):
    authorized_early_exit:      bool
    school_mechanographic_code: str
    study_program_id:           int
    school_class:               str


class WizardRelationships(BaseModel):
    minors_tax_codes:  List[str] = Field(default_factory=list)
    parents_tax_codes: List[str] = Field(default_factory=list)


class PersonWizardPayload(BaseModel):
    general_data:            WizardGeneralData
    roles:                   List[str]
    member_data:             Optional[WizardMemberData]            = None
    staff_data:              Optional[WizardStaffData]             = None
    admin_data:              Optional[WizardAdminData]             = None
    teacher_data:            Optional[WizardTeacherData]           = None
    course_participant_data: Optional[WizardCourseParticipantData] = None
    student_data:            Optional[WizardStudentData]           = None
    relationships:           WizardRelationships