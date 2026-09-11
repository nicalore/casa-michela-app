from datetime import date
from decimal import Decimal
from typing import Final, Self

from pydantic import BaseModel, Field, model_validator

from app.core import field_lengths
from app.schemas.person import (
    ParentalRelationshipInput,
    StudentCertificationData,
    StudentEarlyExitData,
    StudentHomeworkTariffData,
    TeacherEducationData,
)
from app.schemas.validators import (
    OptionalOpeningCapitalStr,
    OptionalSentenceCaseStr,
    OptionalTitleCaseStr,
    TitleCaseStr,
    UpperCaseStr,
)

_MISSING_CONSENTS_ERROR: Final[str] = (
    "Per completare l'iscrizione è necessario accettare: {consents}."
)

_MANDATORY_PSYCH_MEETINGS_ERROR: Final[str] = (
    "È necessario prendere atto dei due incontri obbligatori con "
    "lo psicologo."
)

_MISSING_PAYMENT_METHOD_ERROR: Final[str] = (
    "È necessario indicare la modalità di pagamento."
)

_MANDATORY_CONSENTS: Final[tuple[tuple[str, str], ...]] = (
    ("statute_acknowledged", "presa visione dello Statuto"),
    ("regulation_acknowledged", "accettazione del Regolamento"),
    ("video_surveillance_acknowledged", "consapevolezza della videosorveglianza"),
    ("special_category_data_consent", "consenso al trattamento dei dati particolari"),
)


class WizardGeneralData(BaseModel):
    first_name: TitleCaseStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.PERSON_NAME,
    )
    last_name: TitleCaseStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.PERSON_NAME,
    )
    tax_code: str = Field(
        ...,
        min_length=field_lengths.TAX_CODE,
        max_length=field_lengths.TAX_CODE,
    )
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


class WizardMembershipData(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class WizardMemberDataBase(BaseModel):
    memberships: list[WizardMembershipData] = Field(default_factory=list)
    payment_method: str | None = None
    payment_method_other: OptionalSentenceCaseStr = Field(
        None,
        max_length=field_lengths.OTHER_DETAIL,
    )
    statute_acknowledged: bool
    regulation_acknowledged: bool
    video_surveillance_acknowledged: bool
    special_category_data_consent: bool
    newsletter_consent: bool
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

    # Whoever joins owes at least the membership fee and the insurance.
    @model_validator(mode="after")
    def _check_payment_method(self) -> Self:
        if self.payment_method is None:
            raise ValueError(_MISSING_PAYMENT_METHOD_ERROR)

        return self


class WizardStaffData(BaseModel):
    collaboration_type: str
    iban: str | None = Field(None, max_length=field_lengths.IBAN)
    gross_compensation: Decimal | None = Field(None, ge=0, max_digits=10, decimal_places=2)


class WizardAdminData(BaseModel):
    role: str
    other_role: OptionalOpeningCapitalStr = Field(
        None,
        max_length=field_lengths.OTHER_ROLE,
    )


class WizardTeachingCompetence(BaseModel):
    subject_id: int
    study_program_ids: list[int]


class WizardTeacherData(TeacherEducationData):
    competences: list[WizardTeachingCompetence] = Field(default_factory=list)

    service_names: list[str] = Field(default_factory=list)


class WizardCourseParticipantData(BaseModel):
    medical_certificate_expiration: date | None = None
    course_type: str


class WizardPsychologicalSupportData(BaseModel):
    start_date: date


class WizardSchoolEnrollmentData(BaseModel):
    start_year: int
    school_id: int
    study_program_id: int
    school_class: str


class WizardStudentData(
    StudentCertificationData,
    StudentEarlyExitData,
    StudentHomeworkTariffData,
):
    mandatory_psych_meetings_acknowledged: bool
    school_enrollments: list[WizardSchoolEnrollmentData] = Field(default_factory=list)

    @model_validator(mode="after")
    def _check_mandatory_psych_meetings(self) -> Self:
        if self.certification_types and not self.mandatory_psych_meetings_acknowledged:
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
