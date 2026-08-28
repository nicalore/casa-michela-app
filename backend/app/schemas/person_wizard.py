from datetime import date
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.core import field_lengths
from app.schemas.person import (
    ParentalRelationshipInput,
    StudentCertificationData,
    TeacherEducationData,
)

_MISSING_CONSENTS_ERROR: Final[str] = (
    "Per completare l'iscrizione è necessario accettare: {consents}."
)

_MANDATORY_PSYCH_MEETINGS_ERROR: Final[str] = (
    "È necessario prendere atto dei due incontri obbligatori con "
    "lo psicologo."
)

# The consent to special category data and the newsletter one are offered as
# optional switches by the wizard, and asking for them here rejected anyone who
# declined either.
_MANDATORY_CONSENTS: Final[tuple[tuple[str, str], ...]] = (
    ("statute_acknowledged", "presa visione dello Statuto"),
    ("regulation_acknowledged", "accettazione del Regolamento"),
    ("video_surveillance_acknowledged", "consapevolezza della videosorveglianza"),
)


class WizardGeneralData(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=field_lengths.PERSON_NAME)
    last_name: str = Field(..., min_length=1, max_length=field_lengths.PERSON_NAME)
    tax_code: str = Field(
        ...,
        min_length=field_lengths.TAX_CODE,
        max_length=field_lengths.TAX_CODE,
    )
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


class WizardMembershipData(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class WizardMemberDataBase(BaseModel):
    memberships: list[WizardMembershipData] = Field(default_factory=list)
    payment_method: str | None = None
    payment_method_other: str | None = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    statute_acknowledged: bool
    regulation_acknowledged: bool
    video_surveillance_acknowledged: bool
    special_category_data_consent: bool
    newsletter_consent: bool
    consents_signed_at: date | None = None
    emergency_contact_name: str | None = Field(
        None,
        max_length=field_lengths.CONTACT_NAME,
    )
    emergency_contact_phone: str | None = Field(None, max_length=field_lengths.PHONE)
    allergies_notes: str | None = Field(None, max_length=field_lengths.NOTES)
    medications_notes: str | None = Field(None, max_length=field_lengths.NOTES)


# Joining the association is where the consents become mandatory; printing the
# form that collects them is not, so the check lives in the subclass.
class WizardMemberData(WizardMemberDataBase):
    @model_validator(mode="after")
    def _check_mandatory_consents(self) -> Self:
        missing = [
            label
            for field_name, label in _MANDATORY_CONSENTS
            if not getattr(self, field_name)
        ]

        if missing:
            raise ValueError(
                _MISSING_CONSENTS_ERROR.format(consents=", ".join(missing))
            )

        return self


class WizardStaffData(BaseModel):
    collaboration_type: str
    iban: str | None = Field(None, max_length=field_lengths.IBAN)


class WizardAdminData(BaseModel):
    role: str
    other_role: str | None = Field(None, max_length=field_lengths.OTHER_ROLE)


class WizardTeachingCompetence(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class WizardTeacherData(TeacherEducationData):
    competences: list[WizardTeachingCompetence] = Field(default_factory=list)

    service_names: list[str] = Field(default_factory=list)


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


class WizardStudentData(StudentCertificationData):
    authorized_early_exit: bool
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


class PersonWizardPayloadBase(BaseModel):
    general_data: WizardGeneralData
    roles: list[str]
    member_data: WizardMemberDataBase | None = None
    staff_data: WizardStaffData | None = None
    admin_data: WizardAdminData | None = None
    teacher_data: WizardTeacherData | None = None
    course_participant_data: WizardCourseParticipantData | None = None
    psychological_support_data: WizardPsychologicalSupportData | None = None
    student_data: WizardStudentData | None = None
    relationships: WizardRelationships


class PersonWizardPayload(PersonWizardPayloadBase):
    member_data: WizardMemberData | None = None
