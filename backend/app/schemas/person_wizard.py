from datetime import date
from typing import List, Optional

from pydantic import BaseModel, Field, model_validator

from app.schemas.person import ParentalRelationshipInput


class WizardGeneralData(BaseModel):
    first_name:              str  = Field(..., min_length=1)
    last_name:               str  = Field(..., min_length=1)
    tax_code:                str  = Field(..., min_length=16, max_length=16)
    gender:                  str
    birth_date:              date
    birth_city:              str
    birth_nation:            str
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
    memberships:                     List[WizardMembershipData] = Field(default_factory=list)
    payment_method:                  Optional[str]  = None
    payment_method_other:            Optional[str]  = None
    statute_acknowledged:            bool
    regulation_acknowledged:         bool
    video_surveillance_acknowledged: bool
    special_category_data_consent:   bool
    newsletter_consent:              bool
    consents_signed_at:              Optional[date] = None
    emergency_contact_name:          Optional[str]  = None
    emergency_contact_phone:         Optional[str]  = None
    allergies_notes:                 Optional[str]  = None
    medications_notes:               Optional[str]  = None

    # Tutte le dichiarazioni della Sezione 9 del modulo di iscrizione sono
    # obbligatorie, incluso il consenso ai notiziari periodici.
    @model_validator(mode="after")
    def _check_mandatory_consents(self) -> "WizardMemberData":
        missing = []
        if not self.statute_acknowledged:
            missing.append("presa visione dello Statuto")
        if not self.regulation_acknowledged:
            missing.append("accettazione del Regolamento")
        if not self.video_surveillance_acknowledged:
            missing.append("consapevolezza della videosorveglianza")
        if not self.special_category_data_consent:
            missing.append("consenso al trattamento dei dati particolari")
        if not self.newsletter_consent:
            missing.append("consenso alla ricezione dei notiziari periodici")

        if missing:
            raise ValueError(
                "Per completare l'iscrizione è necessario accettare: "
                + ", ".join(missing) + "."
            )

        return self


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


class WizardPsychologicalSupportData(BaseModel):
    start_date: date


class WizardSchoolEnrollmentData(BaseModel):
    start_year:       int
    school_id:        int
    study_program_id: int
    school_class:     str


class WizardStudentData(BaseModel):
    authorized_early_exit:                 bool
    certification_type:                    Optional[str] = None
    certification_other_detail:            Optional[str] = None
    mandatory_psych_meetings_acknowledged: bool
    school_enrollments:                    List[WizardSchoolEnrollmentData] = Field(default_factory=list)

    # Prassi obbligatoria della Sezione 5 del modulo: chi dichiara una
    # certificazione deve prendere atto dei 2 incontri con la psicologa.
    # Non si applica quando certification_type è None (nessuna
    # certificazione dichiarata).
    @model_validator(mode="after")
    def _check_mandatory_psych_meetings(self) -> "WizardStudentData":
        if self.certification_type is not None and not self.mandatory_psych_meetings_acknowledged:
            raise ValueError(
                "In presenza di una certificazione (DSA/BES/ADHD/Altro) è "
                "necessario prendere atto dei 2 incontri obbligatori con "
                "lo psicologo."
            )

        return self


class WizardRelationships(BaseModel):
    minors_tax_codes:  List[ParentalRelationshipInput] = Field(default_factory=list)
    parents_tax_codes: List[ParentalRelationshipInput] = Field(default_factory=list)


class PersonWizardPayload(BaseModel):
    general_data:                WizardGeneralData
    roles:                       List[str]
    member_data:                 Optional[WizardMemberData]               = None
    staff_data:                  Optional[WizardStaffData]                = None
    admin_data:                  Optional[WizardAdminData]                = None
    teacher_data:                Optional[WizardTeacherData]              = None
    course_participant_data:     Optional[WizardCourseParticipantData]    = None
    psychological_support_data:  Optional[WizardPsychologicalSupportData] = None
    student_data:                Optional[WizardStudentData]              = None
    relationships:                WizardRelationships