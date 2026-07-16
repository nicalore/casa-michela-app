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
    school_id: int
    school_name: str
    # Solo visualizzazione: la scuola potrebbe non avere un codice.
    school_mechanographic_code: Optional[str] = None
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
    birth_nation: Optional[str] = None
    birth_province: Optional[str] = None
    residence_type: Optional[str] = None
    residence_address: Optional[str] = None
    residence_street_number: Optional[str] = None
    residence_province: Optional[str] = None
    postal_code: Optional[str] = None
    city: Optional[str] = None
    birth_date: Optional[date] = None
    # Riferite alla relazione ParentalResponsibility tra questo genitore
    # e la persona per cui la lista viene costruita, non al genitore in
    # generale.
    authorized_pickup: bool = True
    pickup_restriction_reason: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ChildInfoResponse(BaseModel):
    fiscal_code: str
    first_name: str
    last_name: str
    gender: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    birth_city: Optional[str] = None
    birth_nation: Optional[str] = None
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
    # Riferite alla relazione ParentalResponsibility tra il genitore per cui
    # la lista viene costruita e questo figlio, non al figlio in generale.
    authorized_pickup: bool = True
    pickup_restriction_reason: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


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
    # Timestamp letto da PersonResponse.teacher_updated_at, usato dal ramo
    # docente di update_person per il controllo di concorrenza ottimistica
    # sulle competenze insegnate (stesso aggregato di update_teacher_competences).
    expected_updated_at: Optional[datetime] = None


class CourseParticipantUpdateData(BaseModel):
    medical_certificate_expiration: date
    course_type: str


class PsychologicalSupportUpdateData(BaseModel):
    """
    Nessun expected_updated_at: come CourseParticipant, questa tabella
    non ha ancora un proprio controllo di concorrenza ottimistica.
    """
    start_date: date


class SchoolEnrollmentUpdateItem(BaseModel):
    start_year: int
    school_id: int
    study_program_id: int
    grade: int


class StudentUpdateData(BaseModel):
    authorized_early_exit: bool
    certification_type: Optional[str] = None
    certification_other_detail: Optional[str] = None
    mandatory_psych_meetings_acknowledged: bool
    # Storico scolastico completo (non più una singola riga "anno corrente").
    # update_person sostituisce in blocco tutte le SchoolEnrollment dello
    # studente con questa lista, con la stessa semantica dell'endpoint
    # dedicato PUT /{tax_code}/school-enrollments: un'unica fonte di verità
    # per la scrittura degli anni scolastici, evitando che le due rotte
    # scrivano lo stesso aggregato con logiche diverse (RNF-IAM-REL-07).
    school_enrollments: List[SchoolEnrollmentUpdateItem]
    expected_updated_at: Optional[datetime] = None


class ParentalRelationshipInput(BaseModel):
    """
    Elemento di una lista di relazioni genitoriali (minors_tax_codes o
    parents_tax_codes). authorized_pickup indica se la controparte è
    autorizzata al ritiro anticipato in questa specifica relazione, non
    una proprietà del Genitore o dello Studente presi singolarmente.
    """
    tax_code: str
    authorized_pickup: bool = True
    pickup_restriction_reason: Optional[str] = None


class RelationshipsUpdate(BaseModel):
    minors_tax_codes: List[ParentalRelationshipInput] = []
    parents_tax_codes: List[ParentalRelationshipInput] = []


class MembershipUpdateItem(BaseModel):
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int
    revocation: str


class PersonMembershipsUpdate(BaseModel):
    collaborating_active: bool
    memberships: List[MembershipUpdateItem]
    # Da qui in giù: tutti opzionali con semantica "campo assente dal JSON
    # = non toccare il valore attuale a DB", non "assente = azzera".
    # Necessario perché questo stesso schema è condiviso da due chiamanti
    # con scope diversi: update_person_memberships (tab iscrizioni, non
    # tocca mai questi campi) e update_person (dialog di modifica
    # completo, che li tocca solo se ha una card dedicata per quel campo
    # — es. nessuna card Consensi nel dialog di modifica). Il backend
    # distingue "assente" da "presente ma null" via model_fields_set,
    # non un semplice controllo `is None`.
    payment_method: Optional[str] = None
    payment_method_other: Optional[str] = None
    statute_acknowledged: Optional[bool] = None
    regulation_acknowledged: Optional[bool] = None
    video_surveillance_acknowledged: Optional[bool] = None
    special_category_data_consent: Optional[bool] = None
    newsletter_consent: Optional[bool] = None
    consents_signed_at: Optional[date] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    allergies_notes: Optional[str] = None
    medications_notes: Optional[str] = None
    # Timestamp letto dal client al momento del caricamento della persona
    # (PersonResponse.member_updated_at). Usato per il controllo di
    # concorrenza ottimistica in update_person_memberships e nel ramo
    # membership di update_person. Opzionale per non rompere eventuali
    # chiamate esistenti che non lo mandano ancora. Copre l'intero
    # aggregato Member, quindi anche i nuovi campi sopra (pagamento,
    # consensi, sicurezza minore).
    expected_updated_at: Optional[datetime] = None


class PersonUpdatePayload(BaseModel):
    general_data: GeneralDataUpdate
    roles: List[str]
    member_data: Optional[PersonMembershipsUpdate] = None
    staff_data: Optional[StaffUpdateData] = None
    admin_data: Optional[AdminUpdateData] = None
    teacher_data: Optional[TeacherUpdateData] = None
    course_participant_data: Optional[CourseParticipantUpdateData] = None
    psychological_support_data: Optional[PsychologicalSupportUpdateData] = None
    student_data: Optional[StudentUpdateData] = None
    relationships: Optional[RelationshipsUpdate] = None


class RevokeMembershipPayload(BaseModel):
    revocation_type: str
    # Stesso motivo di PersonMembershipsUpdate.expected_updated_at.
    expected_updated_at: Optional[datetime] = None


class PersonSchoolEnrollmentsUpdate(BaseModel):
    enrollments: List[SchoolEnrollmentUpdateItem]
    # Timestamp letto da PersonResponse.student_updated_at, usato dal
    # controllo di concorrenza ottimistica in update_person_school_enrollments.
    expected_updated_at: Optional[datetime] = None


class ParentUpdatePayload(BaseModel):
    parent_tax_code: str
    authorized_pickup: bool = True
    pickup_restriction_reason: Optional[str] = None


class TeacherSubjectResponse(BaseModel):
    subject_id: int
    subject_name: str
    subject_area: str
    study_program_ids: List[int]
    study_programs: List[str]

    model_config = ConfigDict(from_attributes=True)


class PersonTeacherCompetencesUpdate(BaseModel):
    competences: List[TeacherCompetenceUpdateItem]
    # Timestamp letto da PersonResponse.teacher_updated_at, usato dal
    # controllo di concorrenza ottimistica in update_teacher_competences.
    expected_updated_at: Optional[datetime] = None


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
    birth_nation: Optional[str] = None
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

    certification_type: Optional[str] = None
    certification_other_detail: Optional[str] = None
    mandatory_psych_meetings_acknowledged: Optional[bool] = None

    payment_method: Optional[str] = None
    payment_method_other: Optional[str] = None
    statute_acknowledged: Optional[bool] = None
    regulation_acknowledged: Optional[bool] = None
    video_surveillance_acknowledged: Optional[bool] = None
    special_category_data_consent: Optional[bool] = None
    newsletter_consent: Optional[bool] = None
    consents_signed_at: Optional[date] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    allergies_notes: Optional[str] = None
    medications_notes: Optional[str] = None
    # None = non aderisce al servizio di sostegno psicologico.
    psychological_support_start_date: Optional[date] = None

    iban: Optional[str] = None
    admin_role: Optional[str] = None
    admin_other_role: Optional[str] = None
    school_education: Optional[str] = None
    university_education: Optional[str] = None
    medical_certificate_expiration: Optional[date] = None

    # Timestamp dei tre aggregati soggetti a controllo di concorrenza
    # ottimistica (RNF-IAM-REL-07). None se la persona non possiede il
    # relativo profilo. Vanno riportati indietro come expected_updated_at
    # nei rispettivi endpoint di modifica.
    member_updated_at: Optional[datetime] = None
    student_updated_at: Optional[datetime] = None
    teacher_updated_at: Optional[datetime] = None

    memberships: Optional[List[MembershipResponse]] = None
    school_enrollments: Optional[List[SchoolEnrollmentResponse]] = None
    parents: Optional[List[ParentInfoResponse]] = None
    children: Optional[List[ChildInfoResponse]] = None
    teacher_subjects: Optional[List[TeacherSubjectResponse]] = None

    model_config = ConfigDict(from_attributes=True)