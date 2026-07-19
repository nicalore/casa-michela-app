from datetime import date
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.schemas.person import ParentalRelationshipInput

_MISSING_CONSENTS_ERROR: Final[str] = (
    "Per completare l'iscrizione è necessario accettare: {consents}."
)

_MANDATORY_PSYCH_MEETINGS_ERROR: Final[str] = (
    "In presenza di una certificazione (DSA/BES/ADHD/Altro) è "
    "necessario prendere atto dei 2 incontri obbligatori con "
    "lo psicologo."
)


class WizardGeneralData(BaseModel):
    first_name: str = Field(..., min_length=1)
    last_name: str = Field(..., min_length=1)
    tax_code: str = Field(..., min_length=16, max_length=16)
    gender: str
    birth_date: date
    birth_city: str
    birth_nation: str
    birth_province: str = Field(..., max_length=2)
    residence_type: str
    residence_address: str
    residence_street_number: str
    residence_city: str
    residence_province: str = Field(..., max_length=2)
    postal_code: str = Field(..., max_length=5)
    email: str
    phone: str


class WizardMembershipData(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class WizardMemberData(BaseModel):
    memberships: list[WizardMembershipData] = Field(default_factory=list)
    payment_method: str | None = None
    payment_method_other: str | None = None
    statute_acknowledged: bool
    regulation_acknowledged: bool
    video_surveillance_acknowledged: bool
    special_category_data_consent: bool
    newsletter_consent: bool
    consents_signed_at: date | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    allergies_notes: str | None = None
    medications_notes: str | None = None

    @model_validator(mode="after")
    def _check_mandatory_consents(self) -> Self:
        missing: list[str] = []

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
                _MISSING_CONSENTS_ERROR.format(consents=", ".join(missing))
            )

        return self


class WizardStaffData(BaseModel):
    collaboration_type: str
    iban: str | None = None


class WizardAdminData(BaseModel):
    role: str
    other_role: str | None = None


class WizardTeachingCompetence(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class WizardTeacherData(BaseModel):
    school_education: str | None = None
    university_education: str | None = None
    competences: list[WizardTeachingCompetence] = Field(default_factory=list)


class WizardCourseParticipantData(BaseModel):
    medical_certificate_expiration: date
    course_type: str


class WizardPsychologicalSupportData(BaseModel):
    start_date: date


class WizardSchoolEnrollmentData(BaseModel):
    start_year: int
    school_id: int
    study_program_id: int
    school_class: str


class WizardStudentData(BaseModel):
    authorized_early_exit: bool
    certification_type: str | None = None
    certification_other_detail: str | None = None
    mandatory_psych_meetings_acknowledged: bool
    school_enrollments: list[WizardSchoolEnrollmentData] = Field(default_factory=list)

    @model_validator(mode="after")
    def _check_mandatory_psych_meetings(self) -> Self:
        if (
            self.certification_type is not None
            and not self.mandatory_psych_meetings_acknowledged
        ):
            raise ValueError(_MANDATORY_PSYCH_MEETINGS_ERROR)

        return self


class WizardRelationships(BaseModel):
    minors_tax_codes: list[ParentalRelationshipInput] = Field(default_factory=list)
    parents_tax_codes: list[ParentalRelationshipInput] = Field(default_factory=list)


class PersonWizardPayload(BaseModel):
    general_data: WizardGeneralData
    roles: list[str]
    member_data: WizardMemberData | None = None
    staff_data: WizardStaffData | None = None
    admin_data: WizardAdminData | None = None
    teacher_data: WizardTeacherData | None = None
    course_participant_data: WizardCourseParticipantData | None = None
    psychological_support_data: WizardPsychologicalSupportData | None = None
    student_data: WizardStudentData | None = None
    relationships: WizardRelationships