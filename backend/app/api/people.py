import shutil
from datetime import UTC, date, datetime
from typing import Annotated, Any, Final

import resend
from fastapi import APIRouter, File, HTTPException, UploadFile, status
from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from sqlalchemy.sql.base import ExecutableOption

from app.api.dependencies import DbSession
from app.core.config import settings
from app.core.labels import (
    roman_numeral,
    translate_collaboration_type,
    translate_course_type,
    translate_education_level,
)
from app.core.optimistic_concurrency import assert_not_stale
from app.core.storage import PROFILE_IMAGES_DIR, PROFILE_IMAGES_URL_PREFIX
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.course_participant import CourseParticipant, CourseTypeEnum
from app.models.member import Member, PaymentMethodEnum
from app.models.membership import Membership, MembershipRevocationEnum
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import GenderEnum, Person
from app.models.psychological_support import PsychologicalSupport
from app.models.psychologist import Psychologist
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.service import Service
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.student import CertificationTypeEnum, Student
from app.models.teacher import Teacher
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence
from app.schemas.person import (
    AdminUpdateData,
    ChildInfoResponse,
    CourseParticipantUpdateData,
    GeneralDataUpdate,
    MembershipResponse,
    ParentInfoResponse,
    ParentUpdatePayload,
    PersonMembershipsUpdate,
    PersonResponse,
    PersonSchoolEnrollmentsUpdate,
    PersonTeacherCompetencesUpdate,
    PersonUpdatePayload,
    PsychologicalSupportUpdateData,
    RelationshipsUpdate,
    RevokeMembershipPayload,
    SchoolEnrollmentResponse,
    StaffUpdateData,
    StudentUpdateData,
    TeacherProgramResponse,
    TeacherSubjectResponse,
    TeacherUpdateData,
)
from app.schemas.person_wizard import PersonWizardPayload
from app.services.person_wizard_service import create_person_from_wizard
from app.services.role_service import RoleService

router = APIRouter(prefix="/people", tags=["people"])

resend.api_key = settings.resend_api_key

_ROLE_PARENT: Final[str] = "Genitore"
_ROLE_MEMBER: Final[str] = "Associato"
_ROLE_COURSE_PARTICIPANT: Final[str] = "Corsista"
_ROLE_STUDENT: Final[str] = "Studente"
_ROLE_ADMIN: Final[str] = "Amministratore"
_ROLE_TEACHER: Final[str] = "Docente"
_ROLE_PSYCHOLOGIST: Final[str] = "Psicologo"

# The write side of the API speaks the same names in upper case: deriving the
# codes keeps the read/write round trip from drifting apart.
_ROLE_CODE_PARENT: Final[str] = _ROLE_PARENT.upper()
_ROLE_CODE_MEMBER: Final[str] = _ROLE_MEMBER.upper()
_ROLE_CODE_COURSE_PARTICIPANT: Final[str] = _ROLE_COURSE_PARTICIPANT.upper()
_ROLE_CODE_STUDENT: Final[str] = _ROLE_STUDENT.upper()
_ROLE_CODE_ADMIN: Final[str] = _ROLE_ADMIN.upper()
_ROLE_CODE_TEACHER: Final[str] = _ROLE_TEACHER.upper()
_ROLE_CODE_PSYCHOLOGIST: Final[str] = _ROLE_PSYCHOLOGIST.upper()

_MEMBER_ROLE_CODES: Final[frozenset[str]] = frozenset(
    {
        _ROLE_CODE_MEMBER,
        _ROLE_CODE_STUDENT,
        _ROLE_CODE_COURSE_PARTICIPANT,
        _ROLE_CODE_TEACHER,
        _ROLE_CODE_ADMIN,
        _ROLE_CODE_PSYCHOLOGIST,
    }
)

_STAFF_ROLE_CODES: Final[frozenset[str]] = frozenset(
    {
        _ROLE_CODE_TEACHER,
        _ROLE_CODE_ADMIN,
        _ROLE_CODE_PSYCHOLOGIST,
    }
)

_MEMBER_OPTIONAL_FIELDS: Final[tuple[str, ...]] = (
    "statute_acknowledged",
    "regulation_acknowledged",
    "video_surveillance_acknowledged",
    "special_category_data_consent",
    "newsletter_consent",
    "consents_signed_at",
    "emergency_contact_name",
    "emergency_contact_phone",
    "allergies_notes",
    "medications_notes",
)

_MEMBERSHIPS_LABEL: Final[str] = "Le iscrizioni"
_SCHOOL_ENROLLMENTS_LABEL: Final[str] = "Le iscrizioni scolastiche"
_TEACHING_SUBJECTS_LABEL: Final[str] = "Le discipline insegnate"
_TEACHER_DATA_LABEL: Final[str] = "I dati del docente"

_PERSON_NOT_FOUND_ERROR: Final[str] = "Persona non trovata"
_TAX_CODE_IMMUTABLE_ERROR: Final[str] = (
    "La modifica del Codice Fiscale non è consentita per preservare "
    "l'integrità dei dati storici."
)
_PSYCHOLOGIST_SUPPORT_ERROR: Final[str] = (
    "Uno Psicologo non può essere iscritto al servizio di sostegno psicologico."
)
_EMPTY_SCHOOL_HISTORY_ERROR: Final[str] = (
    "Impossibile salvare lo storico scolastico vuoto. "
    "È necessaria almeno un'iscrizione."
)
_DUPLICATE_ENROLLMENT_YEAR_ERROR: Final[str] = (
    "Non è possibile registrare più di un'iscrizione scolastica per lo stesso anno."
)
_DUPLICATE_CONTACT_ERROR: Final[str] = (
    "L'email o il numero di telefono risultano già associati a un'altra "
    "anagrafica nel sistema."
)
_CONSTRAINT_ERROR: Final[str] = "Errore di validazione dei vincoli del database."
_INTERNAL_ERROR: Final[str] = (
    "Errore interno del server durante l'aggiornamento: {error}"
)
_UPDATE_SUCCESS_MESSAGE: Final[str] = "Anagrafica aggiornata con successo"

_MAX_PARENTS: Final[int] = 2

_NO_STUDENT_PROFILE_ERROR: Final[str] = "L'utente non possiede un profilo da studente."
_NO_MEMBER_PROFILE_ERROR: Final[str] = "L'utente non possiede un profilo da associato."
_NO_TEACHER_PROFILE_ERROR: Final[str] = "L'utente non possiede un profilo da docente."
_NO_PARENT_PROFILE_ERROR: Final[str] = (
    "Il soggetto selezionato non ha un profilo genitore."
)
_NEW_PARENT_NO_PROFILE_ERROR: Final[str] = (
    "Il nuovo soggetto selezionato non ha un profilo genitore."
)
_PARENT_ALREADY_LINKED_ERROR: Final[str] = (
    "Questo genitore è già associato a questa persona."
)
_NEW_PARENT_ALREADY_LINKED_ERROR: Final[str] = (
    "Il nuovo genitore è già associato a questa persona."
)
_MAX_PARENTS_ERROR: Final[str] = "Numero massimo di genitori (2) già raggiunto."
_PARENTAL_LINK_NOT_FOUND_ERROR: Final[str] = "Associazione genitoriale non trovata."
_EMPTY_MEMBERSHIPS_ERROR: Final[str] = (
    "Impossibile salvare lo storico iscrizioni vuoto. "
    "È necessaria almeno un'iscrizione."
)
_DUPLICATE_MEMBERSHIP_YEAR_ERROR: Final[str] = (
    "Non è possibile registrare più di un'iscrizione per lo stesso anno."
)
_NO_MEMBERSHIP_TO_REVOKE_ERROR: Final[str] = "Nessuna iscrizione trovata da revocare."
_MEMBERSHIP_ALREADY_REVOKED_ERROR: Final[str] = (
    "L'iscrizione per l'anno corrente risulta già revocata."
)
_EMPTY_COMPETENCES_ERROR: Final[str] = (
    "Impossibile svuotare le discipline. Un docente deve insegnare almeno una "
    "materia o seguire almeno un servizio."
)
_UNKNOWN_SERVICES_ERROR: Final[str] = "Alcuni servizi indicati non esistono: {names}."

_GENERIC_COMMIT_ERROR: Final[str] = "Errore: {error}"
_RAW_COMMIT_ERROR: Final[str] = "{error}"
_REVOKE_COMMIT_ERROR: Final[str] = "Errore durante la revoca dell'iscrizione: {error}"
_WIZARD_CREATE_ERROR: Final[str] = "Errore durante la creazione della persona: {error}"
_REPORT_EMAIL_ERROR: Final[str] = "Impossibile inviare la mail tramite Resend: {error}"

_SCHOOL_YEARS_UPDATED_MESSAGE: Final[str] = "Anni scolastici aggiornati con successo!"
_PARENT_ADDED_MESSAGE: Final[str] = "Genitore aggiunto con successo"
_PICKUP_UPDATED_MESSAGE: Final[str] = "Autorizzazione al ritiro aggiornata con successo"
_PARENT_UPDATED_MESSAGE: Final[str] = "Genitore aggiornato con successo"
_LINK_REMOVED_MESSAGE: Final[str] = "Associazione rimossa con successo"
_REPORT_SENT_MESSAGE: Final[str] = "Segnalazione inviata correttamente"
_PERSON_CREATED_MESSAGE: Final[str] = "Persona creata con successo"
_MEMBERSHIPS_UPDATED_MESSAGE: Final[str] = "Iscrizioni aggiornate con successo"
_MEMBERSHIP_REVOKED_MESSAGE: Final[str] = "Iscrizione revocata con successo"
_COMPETENCES_UPDATED_MESSAGE: Final[str] = "Discipline aggiornate con successo"

_REPORT_EMAIL_SENDER: Final[str] = (
    "Associazione Casa Michela <supporto@app.casamichela.it>"
)
_REPORT_EMAIL_RECIPIENT: Final[str] = "nicolo.calore@casamichela.it"
_REPORT_EMAIL_SUBJECT: Final[str] = "Richiesta correzione anagrafica - {full_name}"

_REPORT_FIELD_TEMPLATE: Final[str] = """
    <div style="margin-bottom: 16px;">
        <p style="margin: 0 0 4px 0; font-weight: bold; color: #003C82;">{field}</p>
        <p style="margin: 0; padding: 12px; background-color: #F1F5F9; border-left: 4px solid #003C82; border-radius: 0 4px 4px 0;">
            {value}
        </p>
    </div>
"""

_REPORT_EMAIL_TEMPLATE: Final[str] = """
<div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; color: #333333; line-height: 1.6;">
    <div style="text-align: center; margin-bottom: 30px;">
        <img src="https://primary.jwwb.nl/public/y/k/w/temp-mfffkbfpkmjgalfrjfhx/logo-casamichela-1-high-bl0vca.png?enable-io=true&width=100" alt="Associazione Casa Michela" style="width: 120px; height: auto;" />
        <p style="margin-top: 10px; color: #003C82; font-weight: bold; font-size: 18px;">Associazione Casa Michela</p>
    </div>
    <h2 style="color: #003C82;">Segnalazione Errore Anagrafica</h2>
    <p>Ciao Nicolò,</p>
    <p>È stata inviata una richiesta di correzione per i dati anagrafici di un utente.</p>

    <div style="background-color: #F8FAFC; padding: 20px; border-radius: 8px; border: 1px solid #E2E8F0; margin: 20px 0;">
        <p style="margin: 0 0 8px 0;"><strong>Persona interessata:</strong> {full_name}</p>
        <p style="margin: 0;"><strong>Codice Fiscale Attuale:</strong> {tax_code}</p>
    </div>

    <h3 style="color: #003C82; margin-top: 30px; margin-bottom: 15px;">Correzioni e modifiche richieste:</h3>
    {fields}
</div>
"""

_ADMIN_UNIQUENESS_ERRORS: Final[dict[str, str]] = {
    "uq_administrator_president": (
        "Esiste già un Presidente configurato all'interno del sistema."
    ),
    "uq_administrator_vice_president": (
        "Esiste già un Vice Presidente configurato all'interno del sistema."
    ),
    "uq_administrator_treasurer": (
        "Esiste già un Tesoriere configurato all'interno del sistema."
    ),
}


def _admin_role_uniqueness_error_detail(error_message: str) -> str | None:
    for constraint_name, detail in _ADMIN_UNIQUENESS_ERRORS.items():
        if constraint_name in error_message:
            return detail

    return None


def _latest_enrollment(enrollments: list[SchoolEnrollment]) -> SchoolEnrollment | None:
    if not enrollments:
        return None

    return max(enrollments, key=lambda enrollment: enrollment.start_year)


def _map_child_info(relationship: ParentalResponsibility) -> ChildInfoResponse:
    child = relationship.child

    school_name = None
    school_class = None
    study_program = None

    student = child.member_profile.student_profile if child.member_profile else None

    if student is not None:
        latest = _latest_enrollment(student.school_enrollments)

        if latest is not None:
            school_class = roman_numeral(latest.grade)
            school_study_program = latest.school_study_program

            if school_study_program is not None:
                if school_study_program.school:
                    school_name = school_study_program.school.name

                if school_study_program.study_program:
                    study_program = school_study_program.study_program.display_name

    return ChildInfoResponse(
        fiscal_code=child.tax_code,
        first_name=child.first_name,
        last_name=child.last_name,
        gender=child.gender,
        email=child.email,
        phone=child.phone,
        birth_city=child.birth_city,
        birth_nation=child.birth_nation,
        birth_province=child.birth_province,
        residence_type=child.residence_type,
        residence_address=child.residence_address,
        residence_street_number=child.residence_street_number,
        residence_province=child.residence_province,
        postal_code=child.postal_code,
        city=child.residence_city,
        birth_date=child.birth_date,
        school_name=school_name,
        school_class=school_class,
        study_program=study_program,
        authorized_pickup=relationship.authorized_pickup,
        pickup_restriction_reason=relationship.pickup_restriction_reason,
    )


def _map_parent_info(relationship: ParentalResponsibility) -> ParentInfoResponse:
    parent = relationship.parent.person

    return ParentInfoResponse(
        fiscal_code=parent.tax_code,
        first_name=parent.first_name,
        last_name=parent.last_name,
        gender=parent.gender,
        email=parent.email,
        phone=parent.phone,
        birth_city=parent.birth_city,
        birth_nation=parent.birth_nation,
        birth_province=parent.birth_province,
        residence_type=parent.residence_type,
        residence_address=parent.residence_address,
        residence_street_number=parent.residence_street_number,
        residence_province=parent.residence_province,
        postal_code=parent.postal_code,
        city=parent.residence_city,
        birth_date=parent.birth_date,
        authorized_pickup=relationship.authorized_pickup,
        pickup_restriction_reason=relationship.pickup_restriction_reason,
    )


def _map_teacher_subjects(
    teacher: Teacher,
) -> tuple[list[str], list[TeacherSubjectResponse]]:
    subject_names: set[str] = set()
    subjects_by_id: dict[int, dict[str, Any]] = {}

    for competence in teacher.teaching_competences:
        subject = competence.association_subject

        if subject is None:
            continue

        subject_names.add(subject.name)

        if competence.study_program is None:
            continue

        if subject.id not in subjects_by_id:
            subjects_by_id[subject.id] = {
                "subject_id": subject.id,
                "subject_name": subject.name,
                "subject_area": subject.area,
                "subject_description": subject.description,
                "study_programs": [],
            }

        subjects_by_id[subject.id]["study_programs"].append(
            TeacherProgramResponse.model_validate(competence.study_program)
        )

    teacher_subjects = [
        TeacherSubjectResponse(**data) for data in subjects_by_id.values()
    ]

    return sorted(subject_names), teacher_subjects


def _map_person_to_response(person: Person) -> PersonResponse:
    roles: list[str] = []
    children: list[ChildInfoResponse] = []
    memberships: list[MembershipResponse] = []
    school_enrollments: list[SchoolEnrollmentResponse] = []
    taught_subjects: list[str] = []
    teacher_subjects: list[TeacherSubjectResponse] = []
    teacher_services: list[str] = []

    is_active_collaborator = None
    enrollment_year = None
    collaboration_type = None
    course_type = None
    is_medical_certificate_valid = None
    education_level = None
    school_name = None
    school_class = None
    study_program = None
    early_exit = None

    iban = None
    admin_role = None
    admin_other_role = None
    school_education = None
    university_education = None
    medical_certificate_expiration = None

    certification_type = None
    certification_other_detail = None
    mandatory_psych_meetings_acknowledged = None

    payment_method = None
    payment_method_other = None
    statute_acknowledged = None
    regulation_acknowledged = None
    video_surveillance_acknowledged = None
    special_category_data_consent = None
    newsletter_consent = None
    consents_signed_at = None
    emergency_contact_name = None
    emergency_contact_phone = None
    allergies_notes = None
    medications_notes = None
    psychological_support_start_date = None

    member_updated_at = None
    student_updated_at = None
    teacher_updated_at = None

    if person.parent_profile is not None:
        roles.append(_ROLE_PARENT)
        children = [
            _map_child_info(relationship)
            for relationship in person.parent_profile.children_relationships
            if relationship.child
        ]

    parents = [
        _map_parent_info(relationship)
        for relationship in person.parental_relationships
        if relationship.parent.person
    ]

    member = person.member_profile

    if member is not None:
        roles.append(_ROLE_MEMBER)
        is_active_collaborator = member.collaborating_active
        member_updated_at = member.updated_at

        payment_method = member.payment_method
        payment_method_other = member.payment_method_other
        statute_acknowledged = member.statute_acknowledged
        regulation_acknowledged = member.regulation_acknowledged
        video_surveillance_acknowledged = member.video_surveillance_acknowledged
        special_category_data_consent = member.special_category_data_consent
        newsletter_consent = member.newsletter_consent
        consents_signed_at = member.consents_signed_at
        emergency_contact_name = member.emergency_contact_name
        emergency_contact_phone = member.emergency_contact_phone
        allergies_notes = member.allergies_notes
        medications_notes = member.medications_notes

        if member.psychological_support_profile is not None:
            psychological_support_start_date = (
                member.psychological_support_profile.start_date
            )

        if member.memberships:
            first_membership = min(
                member.memberships,
                key=lambda membership: membership.year,
            )
            enrollment_year = str(first_membership.year)

            memberships = [
                MembershipResponse(
                    year=membership.year,
                    start_date=membership.start_date,
                    end_date=membership.end_date,
                    renewal_period_days=membership.renewal_period_days,
                    revocation=membership.revocation,
                )
                for membership in member.memberships
            ]

        if member.course_participant_profile is not None:
            roles.append(_ROLE_COURSE_PARTICIPANT)
            course_profile = member.course_participant_profile
            course_type = translate_course_type(course_profile.course_type)
            medical_certificate_expiration = (
                course_profile.medical_certificate_expiration
            )
            is_medical_certificate_valid = bool(
                medical_certificate_expiration
                and medical_certificate_expiration >= date.today()
            )

        if member.student_profile is not None:
            roles.append(_ROLE_STUDENT)
            student = member.student_profile
            early_exit = student.authorized_early_exit
            student_updated_at = student.updated_at

            certification_type = student.certification_type
            certification_other_detail = student.certification_other_detail
            mandatory_psych_meetings_acknowledged = (
                student.mandatory_psych_meetings_acknowledged
            )

            for enrollment in student.school_enrollments:
                school_study_program = enrollment.school_study_program

                if not (
                    school_study_program
                    and school_study_program.school
                    and school_study_program.study_program
                ):
                    continue

                school_enrollments.append(
                    SchoolEnrollmentResponse(
                        start_year=enrollment.start_year,
                        grade=enrollment.grade,
                        school_id=school_study_program.school_id,
                        school_name=school_study_program.school.name,
                        school_mechanographic_code=(
                            school_study_program.school.mechanographic_code
                        ),
                        study_program_name=school_study_program.study_program.display_name,
                        study_program_id=school_study_program.study_program_id,
                        education_level=translate_education_level(
                            school_study_program.study_program.level
                        )
                        or "",
                    )
                )

            latest = _latest_enrollment(student.school_enrollments)

            if latest is not None:
                school_class = roman_numeral(latest.grade)
                school_study_program = latest.school_study_program

                if school_study_program is not None:
                    if school_study_program.school:
                        school_name = school_study_program.school.name

                    if school_study_program.study_program:
                        study_program = school_study_program.study_program.display_name
                        education_level = translate_education_level(
                            school_study_program.study_program.level
                        )

        if member.staff_profile is not None:
            staff = member.staff_profile
            collaboration_type = translate_collaboration_type(staff.collaboration_type)
            iban = staff.iban

            if staff.administrator_profile is not None:
                roles.append(_ROLE_ADMIN)
                admin_role = staff.administrator_profile.role
                admin_other_role = staff.administrator_profile.other_role

            if staff.teacher_profile is not None:
                roles.append(_ROLE_TEACHER)
                teacher = staff.teacher_profile
                school_education = teacher.school_education
                university_education = teacher.university_education
                teacher_updated_at = teacher.updated_at
                taught_subjects, teacher_subjects = _map_teacher_subjects(teacher)
                teacher_services = sorted(
                    entry.service_name for entry in teacher.teacher_services
                )

            if staff.psychologist_profile is not None:
                roles.append(_ROLE_PSYCHOLOGIST)

    children_count = (
        len(person.parent_profile.children_relationships)
        if person.parent_profile
        else None
    )

    return PersonResponse(
        fiscal_code=person.tax_code,
        first_name=person.first_name,
        last_name=person.last_name,
        roles=roles,
        created_at=person.created_at,
        profile_image_url=person.profile_image_url,
        gender=person.gender,
        email=person.email,
        phone=person.phone,
        birth_city=person.birth_city,
        birth_nation=person.birth_nation,
        birth_province=person.birth_province,
        residence_type=person.residence_type,
        residence_address=person.residence_address,
        residence_street_number=person.residence_street_number,
        residence_province=person.residence_province,
        postal_code=person.postal_code,
        city=person.residence_city,
        birth_date=person.birth_date,
        children_count=children_count,
        is_active_collaborator=is_active_collaborator,
        enrollment_year=enrollment_year,
        collaboration_type=collaboration_type,
        course_type=course_type,
        is_medical_certificate_valid=is_medical_certificate_valid,
        education_level=education_level,
        school_name=school_name,
        school_class=school_class,
        study_program=study_program,
        early_exit=early_exit,
        taught_subjects=taught_subjects,
        memberships=memberships or None,
        school_enrollments=school_enrollments or None,
        parents=parents or None,
        children=children or None,
        teacher_subjects=teacher_subjects or None,
        teacher_services=teacher_services or None,
        member_updated_at=member_updated_at,
        student_updated_at=student_updated_at,
        teacher_updated_at=teacher_updated_at,
        iban=iban,
        admin_role=admin_role,
        admin_other_role=admin_other_role,
        school_education=school_education,
        university_education=university_education,
        medical_certificate_expiration=medical_certificate_expiration,
        certification_type=certification_type,
        certification_other_detail=certification_other_detail,
        mandatory_psych_meetings_acknowledged=mandatory_psych_meetings_acknowledged,
        payment_method=payment_method,
        payment_method_other=payment_method_other,
        statute_acknowledged=statute_acknowledged,
        regulation_acknowledged=regulation_acknowledged,
        video_surveillance_acknowledged=video_surveillance_acknowledged,
        special_category_data_consent=special_category_data_consent,
        newsletter_consent=newsletter_consent,
        consents_signed_at=consents_signed_at,
        emergency_contact_name=emergency_contact_name,
        emergency_contact_phone=emergency_contact_phone,
        allergies_notes=allergies_notes,
        medications_notes=medications_notes,
        psychological_support_start_date=psychological_support_start_date,
    )


def _person_load_options() -> tuple[ExecutableOption, ...]:
    children_enrollments = (
        joinedload(Person.parent_profile)
        .joinedload(Parent.children_relationships)
        .joinedload(ParentalResponsibility.child)
        .joinedload(Person.member_profile)
        .joinedload(Member.student_profile)
        .joinedload(Student.school_enrollments)
        .joinedload(SchoolEnrollment.school_study_program)
    )

    own_enrollments = (
        joinedload(Person.member_profile)
        .joinedload(Member.student_profile)
        .joinedload(Student.school_enrollments)
        .joinedload(SchoolEnrollment.school_study_program)
    )

    staff = joinedload(Person.member_profile).joinedload(Member.staff_profile)

    teacher_profile = staff.joinedload(Staff.teacher_profile)
    teaching_competences = teacher_profile.joinedload(Teacher.teaching_competences)

    return (
        joinedload(Person.account),
        children_enrollments.joinedload(SchoolStudyProgram.school),
        children_enrollments.joinedload(SchoolStudyProgram.study_program),
        joinedload(Person.parental_relationships)
        .joinedload(ParentalResponsibility.parent)
        .joinedload(Parent.person),
        joinedload(Person.member_profile).joinedload(Member.memberships),
        joinedload(Person.member_profile).joinedload(Member.course_participant_profile),
        own_enrollments.joinedload(SchoolStudyProgram.school),
        own_enrollments.joinedload(SchoolStudyProgram.study_program),
        staff.joinedload(Staff.administrator_profile),
        teaching_competences.joinedload(TeachingCompetence.association_subject),
        teaching_competences.joinedload(TeachingCompetence.study_program),
        teacher_profile.joinedload(Teacher.teacher_services),
        staff.joinedload(Staff.psychologist_profile),
        joinedload(Person.member_profile).joinedload(
            Member.psychological_support_profile
        ),
    )


async def _get_person_or_404(db: AsyncSession, tax_code: str) -> Person:
    person = await db.get(Person, tax_code.upper())

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return person


async def _update_general_data(
    db: AsyncSession,
    person: Person,
    data: GeneralDataUpdate,
) -> None:
    await db.execute(
        update(Person)
        .where(Person.tax_code == person.tax_code)
        .values(
            first_name=data.first_name,
            last_name=data.last_name,
            gender=GenderEnum(data.gender),
            birth_date=data.birth_date,
            birth_city=data.birth_city,
            birth_nation=data.birth_nation,
            birth_province=data.birth_province,
            residence_type=data.residence_type,
            residence_address=data.residence_address,
            residence_street_number=data.residence_street_number,
            residence_city=data.residence_city,
            residence_province=data.residence_province,
            postal_code=data.postal_code,
            email=data.email,
            phone=data.phone,
        )
    )
    await db.flush()


async def _sync_parent_profile(
    db: AsyncSession,
    person: Person,
    *,
    is_parent: bool,
) -> None:
    if is_parent:
        existing = await db.scalar(
            select(Parent).where(Parent.tax_code == person.tax_code)
        )

        if existing is None:
            db.add(Parent(tax_code=person.tax_code))
            await db.flush()

        return

    await db.execute(delete(Parent).where(Parent.tax_code == person.tax_code))
    await db.flush()


async def _create_parental_relationships(
    db: AsyncSession,
    person: Person,
    relationships: RelationshipsUpdate,
    *,
    is_parent: bool,
) -> None:
    # Children are added only when this person actually holds the parent role,
    # while parents of this person are always allowed.
    if is_parent:
        for minor in relationships.minors_tax_codes:
            if minor.tax_code == person.tax_code:
                continue

            db.add(
                ParentalResponsibility(
                    parent_tax_code=person.tax_code,
                    child_tax_code=minor.tax_code,
                    authorized_pickup=minor.authorized_pickup,
                    pickup_restriction_reason=(
                        minor.pickup_restriction_reason
                        if not minor.authorized_pickup
                        else None
                    ),
                )
            )

    for parent_item in relationships.parents_tax_codes:
        if parent_item.tax_code == person.tax_code:
            continue

        db.add(
            ParentalResponsibility(
                parent_tax_code=parent_item.tax_code,
                child_tax_code=person.tax_code,
                authorized_pickup=parent_item.authorized_pickup,
                pickup_restriction_reason=(
                    parent_item.pickup_restriction_reason
                    if not parent_item.authorized_pickup
                    else None
                ),
            )
        )

    await db.flush()


async def _update_member_data(
    db: AsyncSession,
    person: Person,
    member: Member,
    member_data: PersonMembershipsUpdate,
) -> None:
    assert_not_stale(
        member,
        member_data.expected_updated_at,
        entity_label=_MEMBERSHIPS_LABEL,
    )

    # Fields absent from the payload keep their stored value instead of being
    # cleared: this schema is shared by callers with different scopes.
    provided_fields = member_data.model_fields_set

    update_values: dict[str, Any] = {
        "collaborating_active": member_data.collaborating_active,
        "updated_at": datetime.now(UTC),
    }

    if provided_fields & {"payment_method", "payment_method_other"}:
        payment_method = (
            PaymentMethodEnum(member_data.payment_method)
            if member_data.payment_method
            else None
        )
        update_values["payment_method"] = payment_method
        update_values["payment_method_other"] = (
            member_data.payment_method_other
            if payment_method == PaymentMethodEnum.OTHER
            else None
        )

    for field_name in _MEMBER_OPTIONAL_FIELDS:
        if field_name in provided_fields:
            update_values[field_name] = getattr(member_data, field_name)

    await db.execute(
        update(Member).where(Member.tax_code == person.tax_code).values(**update_values)
    )
    await db.execute(
        delete(Membership).where(Membership.member_tax_code == person.tax_code)
    )
    await db.flush()

    for membership_data in member_data.memberships:
        db.add(
            Membership(
                member_tax_code=person.tax_code,
                year=membership_data.year,
                start_date=membership_data.start_date,
                end_date=membership_data.end_date,
                renewal_period_days=membership_data.renewal_period_days,
                revocation=MembershipRevocationEnum(membership_data.revocation),
            )
        )

    await db.flush()


async def _sync_student_profile(
    db: AsyncSession,
    person: Person,
    student_data: StudentUpdateData,
) -> None:
    if not student_data.school_enrollments:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_EMPTY_SCHOOL_HISTORY_ERROR,
        )

    years = [enrollment.start_year for enrollment in student_data.school_enrollments]

    if len(years) != len(set(years)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_ENROLLMENT_YEAR_ERROR,
        )

    current_student = await db.scalar(
        select(Student).where(Student.tax_code == person.tax_code)
    )

    certification_type = (
        CertificationTypeEnum(student_data.certification_type)
        if student_data.certification_type
        else None
    )
    certification_other_detail = (
        student_data.certification_other_detail
        if certification_type == CertificationTypeEnum.OTHER
        else None
    )

    if current_student is not None:
        # Checked before writing any field, otherwise a conflict would still
        # leave partial data behind.
        assert_not_stale(
            current_student,
            student_data.expected_updated_at,
            entity_label=_SCHOOL_ENROLLMENTS_LABEL,
        )
        await db.execute(
            update(Student)
            .where(Student.tax_code == person.tax_code)
            .values(
                authorized_early_exit=student_data.authorized_early_exit,
                certification_type=certification_type,
                certification_other_detail=certification_other_detail,
                mandatory_psych_meetings_acknowledged=(
                    student_data.mandatory_psych_meetings_acknowledged
                ),
                updated_at=datetime.now(UTC),
            )
        )
    else:
        db.add(
            Student(
                tax_code=person.tax_code,
                authorized_early_exit=student_data.authorized_early_exit,
                certification_type=certification_type,
                certification_other_detail=certification_other_detail,
                mandatory_psych_meetings_acknowledged=(
                    student_data.mandatory_psych_meetings_acknowledged
                ),
            )
        )
        await db.flush()

    # The whole school history is replaced, with the same semantics as the
    # dedicated endpoint: this is the single source of truth for the school
    # years, so anagraphic data and history travel in one atomic call under a
    # single concurrency check.
    await db.execute(
        delete(SchoolEnrollment).where(
            SchoolEnrollment.student_tax_code == person.tax_code
        )
    )
    await db.flush()

    for enrollment_data in student_data.school_enrollments:
        db.add(
            SchoolEnrollment(
                student_tax_code=person.tax_code,
                start_year=enrollment_data.start_year,
                grade=enrollment_data.grade,
                study_program_id=enrollment_data.study_program_id,
                school_id=enrollment_data.school_id,
            )
        )


async def _delete_student_profile(db: AsyncSession, person: Person) -> None:
    await db.execute(
        delete(SchoolEnrollment).where(
            SchoolEnrollment.student_tax_code == person.tax_code
        )
    )
    await db.execute(delete(Student).where(Student.tax_code == person.tax_code))


async def _sync_course_participant(
    db: AsyncSession,
    person: Person,
    data: CourseParticipantUpdateData,
) -> None:
    existing = await db.scalar(
        select(CourseParticipant).where(CourseParticipant.tax_code == person.tax_code)
    )

    if existing is None:
        db.add(
            CourseParticipant(
                tax_code=person.tax_code,
                medical_certificate_expiration=data.medical_certificate_expiration,
                course_type=CourseTypeEnum(data.course_type),
            )
        )
        return

    await db.execute(
        update(CourseParticipant)
        .where(CourseParticipant.tax_code == person.tax_code)
        .values(
            medical_certificate_expiration=data.medical_certificate_expiration,
            course_type=CourseTypeEnum(data.course_type),
        )
    )


async def _sync_psychological_support(
    db: AsyncSession,
    person: Person,
    data: PsychologicalSupportUpdateData,
) -> None:
    existing = await db.scalar(
        select(PsychologicalSupport).where(
            PsychologicalSupport.tax_code == person.tax_code
        )
    )

    if existing is None:
        db.add(
            PsychologicalSupport(
                tax_code=person.tax_code,
                start_date=data.start_date,
            )
        )
        return

    await db.execute(
        update(PsychologicalSupport)
        .where(PsychologicalSupport.tax_code == person.tax_code)
        .values(start_date=data.start_date)
    )


async def _sync_administrator_profile(
    db: AsyncSession,
    person: Person,
    admin_data: AdminUpdateData,
    collaboration_type: CollaborationTypeEnum,
) -> None:
    admin_role = AdministratorRoleEnum(admin_data.role)

    RoleService.assert_collaboration_type_consistent_with_admin_role(
        admin_role, collaboration_type
    )

    other_role = (
        admin_data.other_role if admin_role == AdministratorRoleEnum.OTHER else None
    )

    existing = await db.scalar(
        select(Administrator).where(Administrator.tax_code == person.tax_code)
    )

    if existing is None:
        db.add(
            Administrator(
                tax_code=person.tax_code,
                role=admin_role,
                other_role=other_role,
            )
        )
        return

    await db.execute(
        update(Administrator)
        .where(Administrator.tax_code == person.tax_code)
        .values(role=admin_role, other_role=other_role)
    )


async def _sync_teacher_profile(
    db: AsyncSession,
    person: Person,
    teacher_data: TeacherUpdateData,
) -> None:
    existing = await db.scalar(
        select(Teacher).where(Teacher.tax_code == person.tax_code)
    )

    if existing is not None:
        # Teacher.updated_at carries onupdate=func.now(), so any UPDATE on the
        # row bumps it even when it does not touch the column. The check
        # therefore also covers edits limited to the education fields.
        entity_label = (
            _TEACHING_SUBJECTS_LABEL
            if teacher_data.competences is not None
            else _TEACHER_DATA_LABEL
        )
        assert_not_stale(
            existing,
            teacher_data.expected_updated_at,
            entity_label=entity_label,
        )

        await db.execute(
            update(Teacher)
            .where(Teacher.tax_code == person.tax_code)
            .values(
                school_education=teacher_data.school_education,
                university_education=teacher_data.university_education,
                updated_at=datetime.now(UTC),
            )
        )
    else:
        db.add(
            Teacher(
                tax_code=person.tax_code,
                school_education=teacher_data.school_education,
                university_education=teacher_data.university_education,
            )
        )
        await db.flush()

    if teacher_data.competences is None and teacher_data.service_names is None:
        return

    if teacher_data.competences is not None:
        await db.execute(
            delete(TeachingCompetence).where(
                TeachingCompetence.teacher_tax_code == person.tax_code
            )
        )
        await db.flush()

        for competence_data in teacher_data.competences:
            for study_program_id in competence_data.study_program_ids:
                db.add(
                    TeachingCompetence(
                        teacher_tax_code=person.tax_code,
                        association_subject_id=competence_data.subject_id,
                        study_program_id=study_program_id,
                    )
                )

    if teacher_data.service_names is not None:
        await _replace_teacher_services(db, person.tax_code, teacher_data.service_names)


# Rewrites a teacher's services after checking they exist: without the check a
# wrong name would surface as a foreign key violation, that is a 500 or a message
# that does not name what was wrong.
async def _replace_teacher_services(
    db: AsyncSession,
    tax_code: str,
    service_names: list[str],
) -> None:
    await db.execute(
        delete(TeacherService).where(TeacherService.teacher_tax_code == tax_code)
    )
    await db.flush()

    unique_names = list(dict.fromkeys(service_names))

    if not unique_names:
        return

    existing = set(
        (
            await db.execute(
                select(Service.name).where(Service.name.in_(unique_names))
            )
        )
        .scalars()
        .all()
    )
    missing = [name for name in unique_names if name not in existing]

    if missing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UNKNOWN_SERVICES_ERROR.format(names=", ".join(missing)),
        )

    for name in unique_names:
        db.add(TeacherService(teacher_tax_code=tax_code, service_name=name))


async def _delete_teacher_profile(db: AsyncSession, person: Person) -> None:
    await db.execute(
        delete(TeachingCompetence).where(
            TeachingCompetence.teacher_tax_code == person.tax_code
        )
    )
    await db.execute(
        delete(TeacherService).where(TeacherService.teacher_tax_code == person.tax_code)
    )
    await db.execute(delete(Teacher).where(Teacher.tax_code == person.tax_code))


async def _sync_staff_profiles(
    db: AsyncSession,
    person: Person,
    roles: list[str],
    payload: PersonUpdatePayload,
    staff_data: StaffUpdateData,
) -> None:
    collaboration_type = CollaborationTypeEnum(staff_data.collaboration_type)
    iban = staff_data.iban or None

    existing_staff = await db.scalar(
        select(Staff).where(Staff.tax_code == person.tax_code)
    )

    if existing_staff is None:
        db.add(
            Staff(
                tax_code=person.tax_code,
                collaboration_type=collaboration_type,
                iban=iban,
            )
        )
        await db.flush()
    else:
        await db.execute(
            update(Staff)
            .where(Staff.tax_code == person.tax_code)
            .values(collaboration_type=collaboration_type, iban=iban)
        )

    if _ROLE_CODE_ADMIN in roles and payload.admin_data:
        await _sync_administrator_profile(
            db,
            person,
            payload.admin_data,
            collaboration_type,
        )
    else:
        await db.execute(
            delete(Administrator).where(Administrator.tax_code == person.tax_code)
        )

    if _ROLE_CODE_TEACHER in roles and payload.teacher_data:
        await _sync_teacher_profile(db, person, payload.teacher_data)
    else:
        await _delete_teacher_profile(db, person)

    if _ROLE_CODE_PSYCHOLOGIST in roles:
        existing_psychologist = await db.scalar(
            select(Psychologist).where(Psychologist.tax_code == person.tax_code)
        )

        if existing_psychologist is None:
            db.add(Psychologist(tax_code=person.tax_code))
    else:
        await db.execute(
            delete(Psychologist).where(Psychologist.tax_code == person.tax_code)
        )


async def _delete_staff_profiles(db: AsyncSession, person: Person) -> None:
    await db.execute(
        delete(Administrator).where(Administrator.tax_code == person.tax_code)
    )
    await _delete_teacher_profile(db, person)
    await db.execute(
        delete(Psychologist).where(Psychologist.tax_code == person.tax_code)
    )
    await db.execute(delete(Staff).where(Staff.tax_code == person.tax_code))


async def _delete_all_member_profiles(db: AsyncSession, person: Person) -> None:
    await _delete_student_profile(db, person)
    await db.execute(
        delete(CourseParticipant).where(CourseParticipant.tax_code == person.tax_code)
    )
    await db.execute(
        delete(PsychologicalSupport).where(
            PsychologicalSupport.tax_code == person.tax_code
        )
    )
    await _delete_staff_profiles(db, person)
    await db.execute(
        delete(Membership).where(Membership.member_tax_code == person.tax_code)
    )
    await db.execute(delete(Member).where(Member.tax_code == person.tax_code))


async def _commit_person_update(db: AsyncSession) -> None:
    try:
        await db.commit()

    except IntegrityError as err:
        await db.rollback()
        error_message = str(err).lower()
        admin_uniqueness_detail = _admin_role_uniqueness_error_detail(error_message)

        if admin_uniqueness_detail:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=admin_uniqueness_detail,
            ) from err

        if "unique constraint" in error_message or "duplicate key" in error_message:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_DUPLICATE_CONTACT_ERROR,
            ) from err

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CONSTRAINT_ERROR,
        ) from err

    except Exception as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_INTERNAL_ERROR.format(error=err),
        ) from err


@router.get("/", response_model=list[PersonResponse])
async def get_people(db: DbSession) -> list[PersonResponse]:
    stmt = select(Person).options(*_person_load_options())
    result = await db.execute(stmt)
    people = result.unique().scalars().all()

    return [_map_person_to_response(person) for person in people]


@router.get("/{tax_code}", response_model=PersonResponse)
async def get_person(tax_code: str, db: DbSession) -> PersonResponse:
    stmt = (
        select(Person)
        .options(*_person_load_options())
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return _map_person_to_response(person)


@router.put("/{tax_code}", status_code=status.HTTP_200_OK)
async def update_person(
    tax_code: str,
    payload: PersonUpdatePayload,
    db: DbSession,
) -> dict[str, str]:
    person = await _get_person_or_404(db, tax_code)

    if payload.general_data.tax_code.upper() != person.tax_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_TAX_CODE_IMMUTABLE_ERROR,
        )

    await _update_general_data(db, person, payload.general_data)

    roles = [role.upper() for role in payload.roles]

    if _ROLE_CODE_PSYCHOLOGIST in roles and payload.psychological_support_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_PSYCHOLOGIST_SUPPORT_ERROR,
        )

    is_parent = _ROLE_CODE_PARENT in roles

    # Existing relationships are cleared before the Parent profile is touched,
    # then rebuilt afterwards, so the foreign keys never dangle.
    if payload.relationships is not None:
        await db.execute(
            delete(ParentalResponsibility).where(
                or_(
                    ParentalResponsibility.parent_tax_code == person.tax_code,
                    ParentalResponsibility.child_tax_code == person.tax_code,
                )
            )
        )
        await db.flush()

    await _sync_parent_profile(db, person, is_parent=is_parent)

    if payload.relationships is not None:
        await _create_parental_relationships(
            db,
            person,
            payload.relationships,
            is_parent=is_parent,
        )

    if any(role in roles for role in _MEMBER_ROLE_CODES):
        member = await db.scalar(
            select(Member).where(Member.tax_code == person.tax_code)
        )

        if member is None:
            member = Member(tax_code=person.tax_code)
            db.add(member)
            await db.flush()

        if payload.member_data:
            await _update_member_data(db, person, member, payload.member_data)

        if _ROLE_CODE_STUDENT in roles and payload.student_data:
            await _sync_student_profile(db, person, payload.student_data)
        else:
            await _delete_student_profile(db, person)

        if _ROLE_CODE_COURSE_PARTICIPANT in roles and payload.course_participant_data:
            await _sync_course_participant(
                db,
                person,
                payload.course_participant_data,
            )
        else:
            await db.execute(
                delete(CourseParticipant).where(
                    CourseParticipant.tax_code == person.tax_code
                )
            )

        # No dedicated role: the service is open to any member. The guard at
        # the top of this function keeps it from coexisting with PSICOLOGO.
        if payload.psychological_support_data:
            await _sync_psychological_support(
                db,
                person,
                payload.psychological_support_data,
            )
        else:
            await db.execute(
                delete(PsychologicalSupport).where(
                    PsychologicalSupport.tax_code == person.tax_code
                )
            )

        needs_staff = any(role in roles for role in _STAFF_ROLE_CODES)

        if needs_staff and payload.staff_data:
            await _sync_staff_profiles(
                db,
                person,
                roles,
                payload,
                payload.staff_data,
            )
        else:
            await _delete_staff_profiles(db, person)
    else:
        await _delete_all_member_profiles(db, person)

    await _commit_person_update(db)

    return {
        "message": _UPDATE_SUCCESS_MESSAGE,
        "new_tax_code": person.tax_code,
    }


async def _commit_or_500(db: AsyncSession, error_template: str) -> None:
    try:
        await db.commit()

    except Exception as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_template.format(error=err),
        ) from err


async def _load_person_or_404(
    db: AsyncSession,
    tax_code: str,
    *options: ExecutableOption,
) -> Person:
    stmt = select(Person).options(*options).where(Person.tax_code == tax_code.upper())
    person = (await db.execute(stmt)).unique().scalar_one_or_none()

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return person


async def _get_parental_link_or_404(
    db: AsyncSession,
    child_tax_code: str,
    parent_tax_code: str,
) -> ParentalResponsibility:
    stmt = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == child_tax_code.upper(),
        ParentalResponsibility.parent_tax_code == parent_tax_code.upper(),
    )
    link = (await db.execute(stmt)).scalar_one_or_none()

    if link is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PARENTAL_LINK_NOT_FOUND_ERROR,
        )

    return link


async def _assert_parental_link_absent(
    db: AsyncSession,
    child_tax_code: str,
    parent_tax_code: str,
    error_detail: str,
) -> None:
    stmt = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == child_tax_code.upper(),
        ParentalResponsibility.parent_tax_code == parent_tax_code.upper(),
    )

    if (await db.execute(stmt)).scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_detail,
        )


async def _load_parent_with_profile(
    db: AsyncSession,
    parent_tax_code: str,
    error_detail: str,
) -> Person:
    stmt = (
        select(Person)
        .options(joinedload(Person.parent_profile))
        .where(Person.tax_code == parent_tax_code.upper())
    )
    parent = (await db.execute(stmt)).unique().scalar_one_or_none()

    if parent is None or parent.parent_profile is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_detail,
        )

    return parent


def _assert_unique_years(years: list[int], error_detail: str) -> None:
    if len(years) != len(set(years)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_detail,
        )


@router.put("/{tax_code}/school-enrollments", status_code=status.HTTP_200_OK)
async def update_person_school_enrollments(
    tax_code: str,
    payload: PersonSchoolEnrollmentsUpdate,
    db: DbSession,
) -> dict[str, str]:
    if not payload.enrollments:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_EMPTY_SCHOOL_HISTORY_ERROR,
        )

    person = await _load_person_or_404(
        db,
        tax_code,
        joinedload(Person.member_profile)
        .joinedload(Member.student_profile)
        .joinedload(Student.school_enrollments),
    )

    member = person.member_profile

    if member is None or member.student_profile is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_STUDENT_PROFILE_ERROR,
        )

    student = member.student_profile
    assert_not_stale(
        student,
        payload.expected_updated_at,
        entity_label=_SCHOOL_ENROLLMENTS_LABEL,
    )
    _assert_unique_years(
        [enrollment.start_year for enrollment in payload.enrollments],
        _DUPLICATE_ENROLLMENT_YEAR_ERROR,
    )

    student.updated_at = datetime.now(UTC)

    await db.execute(
        delete(SchoolEnrollment).where(
            SchoolEnrollment.student_tax_code == person.tax_code
        )
    )
    await db.flush()

    for enrollment_data in payload.enrollments:
        db.add(
            SchoolEnrollment(
                student_tax_code=person.tax_code,
                start_year=enrollment_data.start_year,
                grade=enrollment_data.grade,
                study_program_id=enrollment_data.study_program_id,
                school_id=enrollment_data.school_id,
            )
        )

    await _commit_or_500(db, _GENERIC_COMMIT_ERROR)

    return {"message": _SCHOOL_YEARS_UPDATED_MESSAGE}


@router.post("/{tax_code}/parents", status_code=status.HTTP_200_OK)
async def add_parental_responsibility(
    tax_code: str,
    payload: ParentUpdatePayload,
    db: DbSession,
) -> dict[str, str]:
    await _load_person_or_404(db, tax_code)
    await _load_parent_with_profile(
        db,
        payload.parent_tax_code,
        _NO_PARENT_PROFILE_ERROR,
    )
    await _assert_parental_link_absent(
        db,
        tax_code,
        payload.parent_tax_code,
        _PARENT_ALREADY_LINKED_ERROR,
    )

    existing_links = await db.execute(
        select(ParentalResponsibility).where(
            ParentalResponsibility.child_tax_code == tax_code.upper()
        )
    )

    if len(existing_links.scalars().all()) >= _MAX_PARENTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MAX_PARENTS_ERROR,
        )

    db.add(
        ParentalResponsibility(
            parent_tax_code=payload.parent_tax_code.upper(),
            child_tax_code=tax_code.upper(),
            authorized_pickup=payload.authorized_pickup,
            pickup_restriction_reason=(
                payload.pickup_restriction_reason
                if not payload.authorized_pickup
                else None
            ),
        )
    )

    await _commit_or_500(db, _RAW_COMMIT_ERROR)

    return {"message": _PARENT_ADDED_MESSAGE}


@router.put("/{tax_code}/parents/{old_parent_tax_code}", status_code=status.HTTP_200_OK)
async def update_parental_responsibility(
    tax_code: str,
    old_parent_tax_code: str,
    payload: ParentUpdatePayload,
    db: DbSession,
) -> dict[str, str]:
    link = await _get_parental_link_or_404(db, tax_code, old_parent_tax_code)

    restriction_reason = (
        payload.pickup_restriction_reason if not payload.authorized_pickup else None
    )

    # Same parent: only the pickup authorization changes, so the row is
    # updated in place instead of being deleted and recreated.
    if payload.parent_tax_code.upper() == old_parent_tax_code.upper():
        link.authorized_pickup = payload.authorized_pickup
        link.pickup_restriction_reason = restriction_reason

        await _commit_or_500(db, _RAW_COMMIT_ERROR)

        return {"message": _PICKUP_UPDATED_MESSAGE}

    await _load_parent_with_profile(
        db,
        payload.parent_tax_code,
        _NEW_PARENT_NO_PROFILE_ERROR,
    )
    await _assert_parental_link_absent(
        db,
        tax_code,
        payload.parent_tax_code,
        _NEW_PARENT_ALREADY_LINKED_ERROR,
    )

    await db.delete(link)
    db.add(
        ParentalResponsibility(
            parent_tax_code=payload.parent_tax_code.upper(),
            child_tax_code=tax_code.upper(),
            authorized_pickup=payload.authorized_pickup,
            pickup_restriction_reason=restriction_reason,
        )
    )

    await _commit_or_500(db, _RAW_COMMIT_ERROR)

    return {"message": _PARENT_UPDATED_MESSAGE}


@router.delete("/{tax_code}/parents/{parent_tax_code}", status_code=status.HTTP_200_OK)
async def delete_parental_responsibility(
    tax_code: str,
    parent_tax_code: str,
    db: DbSession,
) -> dict[str, str]:
    link = await _get_parental_link_or_404(db, tax_code, parent_tax_code)

    await db.delete(link)
    await _commit_or_500(db, _RAW_COMMIT_ERROR)

    return {"message": _LINK_REMOVED_MESSAGE}


@router.post("/{tax_code}/report-error", status_code=status.HTTP_200_OK)
async def report_person_error(
    tax_code: str,
    corrections: dict[str, Any],
    db: DbSession,
) -> dict[str, str]:
    person = await db.get(Person, tax_code)

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    full_name = f"{person.first_name} {person.last_name}"
    fields = "".join(
        _REPORT_FIELD_TEMPLATE.format(field=field, value=value)
        for field, value in corrections.items()
    )

    try:
        resend.Emails.send(
            {
                "from": _REPORT_EMAIL_SENDER,
                "to": _REPORT_EMAIL_RECIPIENT,
                "reply_to": _REPORT_EMAIL_RECIPIENT,
                "subject": _REPORT_EMAIL_SUBJECT.format(full_name=full_name),
                "html": _REPORT_EMAIL_TEMPLATE.format(
                    full_name=full_name,
                    tax_code=person.tax_code,
                    fields=fields,
                ),
            }
        )

    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_REPORT_EMAIL_ERROR.format(error=err),
        ) from err

    return {"status": "success", "message": _REPORT_SENT_MESSAGE}


@router.post("/wizard/", status_code=status.HTTP_201_CREATED)
async def wizard_create_person(
    payload: PersonWizardPayload,
    db: DbSession,
) -> dict[str, str]:
    try:
        new_person = await create_person_from_wizard(db, payload)

    except HTTPException as http_exc:
        await db.rollback()
        raise http_exc from None

    except IntegrityError as err:
        await db.rollback()
        error_message = str(err).lower()
        admin_uniqueness_detail = _admin_role_uniqueness_error_detail(error_message)

        if admin_uniqueness_detail:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=admin_uniqueness_detail,
            ) from err

        if "unique constraint" in error_message or "duplicate key" in error_message:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_DUPLICATE_CONTACT_ERROR,
            ) from err

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CONSTRAINT_ERROR,
        ) from err

    except Exception as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_WIZARD_CREATE_ERROR.format(error=err),
        ) from err

    return {"message": _PERSON_CREATED_MESSAGE, "tax_code": new_person.tax_code}


@router.post("/{tax_code}/image", status_code=status.HTTP_200_OK)
async def upload_profile_image(
    tax_code: str,
    db: DbSession,
    file: Annotated[UploadFile, File()],
) -> dict[str, str]:
    person = await db.get(Person, tax_code)

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    PROFILE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    safe_filename = file.filename or "profile.jpg"
    extension = safe_filename.split(".")[-1] if "." in safe_filename else "jpg"
    destination = PROFILE_IMAGES_DIR / f"{tax_code}.{extension}"

    with destination.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    image_url = f"{PROFILE_IMAGES_URL_PREFIX}/{destination.name}"
    person.profile_image_url = image_url

    await db.commit()

    return {"profile_image_url": image_url}


@router.put("/{tax_code}/memberships", status_code=status.HTTP_200_OK)
async def update_person_memberships(
    tax_code: str,
    payload: PersonMembershipsUpdate,
    db: DbSession,
) -> dict[str, str]:
    if not payload.memberships:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_EMPTY_MEMBERSHIPS_ERROR,
        )

    person = await _load_person_or_404(
        db,
        tax_code,
        joinedload(Person.member_profile).joinedload(Member.memberships),
    )

    member = person.member_profile

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_MEMBER_PROFILE_ERROR,
        )

    assert_not_stale(
        member,
        payload.expected_updated_at,
        entity_label=_MEMBERSHIPS_LABEL,
    )
    _assert_unique_years(
        [membership.year for membership in payload.memberships],
        _DUPLICATE_MEMBERSHIP_YEAR_ERROR,
    )

    member.collaborating_active = payload.collaborating_active
    member.updated_at = datetime.now(UTC)

    await db.execute(
        delete(Membership).where(Membership.member_tax_code == person.tax_code)
    )
    await db.flush()

    for membership_data in payload.memberships:
        db.add(
            Membership(
                member_tax_code=person.tax_code,
                year=membership_data.year,
                start_date=membership_data.start_date,
                end_date=membership_data.end_date,
                renewal_period_days=membership_data.renewal_period_days,
                revocation=MembershipRevocationEnum(membership_data.revocation),
            )
        )

    await _commit_or_500(db, _GENERIC_COMMIT_ERROR)

    return {"message": _MEMBERSHIPS_UPDATED_MESSAGE}


@router.put("/{tax_code}/revoke-membership", status_code=status.HTTP_200_OK)
async def revoke_person_membership(
    tax_code: str,
    payload: RevokeMembershipPayload,
    db: DbSession,
) -> dict[str, str]:
    person = await _load_person_or_404(
        db,
        tax_code,
        joinedload(Person.member_profile).joinedload(Member.memberships),
    )

    member = person.member_profile

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_MEMBER_PROFILE_ERROR,
        )

    assert_not_stale(
        member,
        payload.expected_updated_at,
        entity_label=_MEMBERSHIPS_LABEL,
    )

    if not member.memberships:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_MEMBERSHIP_TO_REVOKE_ERROR,
        )

    latest_membership = max(
        member.memberships,
        key=lambda membership: membership.year,
    )

    if latest_membership.revocation != MembershipRevocationEnum.NO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MEMBERSHIP_ALREADY_REVOKED_ERROR,
        )

    latest_membership.end_date = date.today()
    latest_membership.renewal_period_days = 0
    latest_membership.revocation = MembershipRevocationEnum(payload.revocation_type)

    member.collaborating_active = False
    member.updated_at = datetime.now(UTC)

    await _commit_or_500(db, _REVOKE_COMMIT_ERROR)

    return {"message": _MEMBERSHIP_REVOKED_MESSAGE}


@router.put("/{tax_code}/teacher-competences", status_code=status.HTTP_200_OK)
async def update_teacher_competences(
    tax_code: str,
    payload: PersonTeacherCompetencesUpdate,
    db: DbSession,
) -> dict[str, str]:
    # A teacher who only takes on services is still a teacher: what they cannot
    # be is one who does neither of the two.
    if not payload.competences and not payload.service_names:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_EMPTY_COMPETENCES_ERROR,
        )

    person = await _load_person_or_404(
        db,
        tax_code,
        joinedload(Person.member_profile)
        .joinedload(Member.staff_profile)
        .joinedload(Staff.teacher_profile)
        .joinedload(Teacher.teaching_competences),
    )

    member = person.member_profile
    staff = member.staff_profile if member else None
    teacher = staff.teacher_profile if staff else None

    if teacher is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_TEACHER_PROFILE_ERROR,
        )

    assert_not_stale(
        teacher,
        payload.expected_updated_at,
        entity_label=_TEACHING_SUBJECTS_LABEL,
    )

    teacher.updated_at = datetime.now(UTC)

    await db.execute(
        delete(TeachingCompetence).where(
            TeachingCompetence.teacher_tax_code == person.tax_code
        )
    )
    await db.flush()

    for competence_data in payload.competences:
        for study_program_id in competence_data.study_program_ids:
            db.add(
                TeachingCompetence(
                    teacher_tax_code=person.tax_code,
                    association_subject_id=competence_data.subject_id,
                    study_program_id=study_program_id,
                )
            )

    await _replace_teacher_services(db, person.tax_code, payload.service_names)

    await _commit_or_500(db, _GENERIC_COMMIT_ERROR)

    return {"message": _COMPETENCES_UPDATED_MESSAGE}
