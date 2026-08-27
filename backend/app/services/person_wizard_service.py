from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import GRADE_BY_ROMAN_NUMERAL
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.course_participant import CourseParticipant, CourseTypeEnum
from app.models.member import Member, PaymentMethodEnum
from app.models.membership import Membership
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.psychological_support import PsychologicalSupport
from app.models.psychologist import Psychologist
from app.models.school_enrollment import SchoolEnrollment
from app.models.service import Service
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.student import CertificationTypeEnum, Student
from app.models.teacher import Teacher
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence
from app.schemas.person_wizard import PersonWizardPayload
from app.services.role_service import RoleService

_ROLE_PARENT: Final[str] = "GENITORE"
_ROLE_MEMBER: Final[str] = "ASSOCIATO"
_ROLE_STUDENT: Final[str] = "STUDENTE"
_ROLE_COURSE_PARTICIPANT: Final[str] = "CORSISTA"
_ROLE_TEACHER: Final[str] = "DOCENTE"
_ROLE_ADMIN: Final[str] = "AMMINISTRATORE"
_ROLE_PSYCHOLOGIST: Final[str] = "PSICOLOGO"

_MEMBER_ROLES: Final[frozenset[str]] = frozenset(
    {
        _ROLE_MEMBER,
        _ROLE_STUDENT,
        _ROLE_COURSE_PARTICIPANT,
        _ROLE_TEACHER,
        _ROLE_ADMIN,
        _ROLE_PSYCHOLOGIST,
    }
)

_STAFF_ROLES: Final[frozenset[str]] = frozenset(
    {
        _ROLE_TEACHER,
        _ROLE_ADMIN,
        _ROLE_PSYCHOLOGIST,
    }
)

_PERSON_ALREADY_EXISTS_ERROR: Final[str] = (
    "Una persona con questo codice fiscale è già presente nel sistema."
)

_PSYCHOLOGIST_SUPPORT_ERROR: Final[str] = (
    "Uno Psicologo non può essere iscritto al servizio di sostegno psicologico."
)

_UNKNOWN_SERVICES_ERROR: Final[str] = "Alcuni servizi indicati non esistono: {names}."

_DEFAULT_GRADE: Final[int] = 1


# Existence is checked so a wrong name yields a message, not an FK 500.
async def _add_teacher_services(
    db: AsyncSession,
    tax_code: str,
    service_names: list[str],
) -> None:
    unique_names = list(dict.fromkeys(service_names))

    if not unique_names:
        return

    existing = set(
        (await db.execute(select(Service.name).where(Service.name.in_(unique_names))))
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


async def create_person_from_wizard(
    db: AsyncSession,
    payload: PersonWizardPayload,
) -> Person:
    existing_person = await db.get(Person, payload.general_data.tax_code)

    if existing_person:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_PERSON_ALREADY_EXISTS_ERROR,
        )

    roles = payload.roles

    if _ROLE_PSYCHOLOGIST in roles and payload.psychological_support_data is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_PSYCHOLOGIST_SUPPORT_ERROR,
        )

    general_data = payload.general_data

    person = Person(
        tax_code=general_data.tax_code,
        first_name=general_data.first_name,
        last_name=general_data.last_name,
        gender=general_data.gender,
        birth_date=general_data.birth_date,
        birth_city=general_data.birth_city,
        birth_nation=general_data.birth_nation,
        birth_province=general_data.birth_province,
        residence_type=general_data.residence_type,
        residence_address=general_data.residence_address,
        residence_street_number=general_data.residence_street_number,
        residence_city=general_data.residence_city,
        residence_province=general_data.residence_province,
        postal_code=general_data.postal_code,
        email=general_data.email,
        phone=general_data.phone,
    )

    db.add(person)

    if _ROLE_PARENT in roles:
        db.add(Parent(tax_code=person.tax_code))

    needs_member = any(role in roles for role in _MEMBER_ROLES)

    if needs_member:
        member = Member(tax_code=person.tax_code)
        db.add(member)

        if payload.member_data:
            member_data = payload.member_data
            payment_method = (
                PaymentMethodEnum(member_data.payment_method)
                if member_data.payment_method
                else None
            )

            member.payment_method = payment_method
            member.payment_method_other = (
                member_data.payment_method_other
                if payment_method == PaymentMethodEnum.OTHER
                else None
            )
            member.statute_acknowledged = member_data.statute_acknowledged
            member.regulation_acknowledged = member_data.regulation_acknowledged
            member.video_surveillance_acknowledged = (
                member_data.video_surveillance_acknowledged
            )
            member.special_category_data_consent = (
                member_data.special_category_data_consent
            )
            member.newsletter_consent = member_data.newsletter_consent
            member.consents_signed_at = member_data.consents_signed_at
            member.emergency_contact_name = member_data.emergency_contact_name
            member.emergency_contact_phone = member_data.emergency_contact_phone
            member.allergies_notes = member_data.allergies_notes
            member.medications_notes = member_data.medications_notes

            for membership_data in member_data.memberships:
                db.add(
                    Membership(
                        member_tax_code=person.tax_code,
                        year=membership_data.year,
                        start_date=membership_data.start_date,
                        end_date=membership_data.end_date,
                        renewal_period_days=membership_data.renewal_period_days,
                        revocation=membership_data.revocation,
                    )
                )

        if _ROLE_STUDENT in roles and payload.student_data:
            student_data = payload.student_data
            certification_type = (
                CertificationTypeEnum(student_data.certification_type)
                if student_data.certification_type
                else None
            )

            db.add(
                Student(
                    tax_code=person.tax_code,
                    authorized_early_exit=student_data.authorized_early_exit,
                    certification_type=certification_type,
                    certification_other_detail=(
                        student_data.certification_other_detail
                        if certification_type == CertificationTypeEnum.OTHER
                        else None
                    ),
                    certification_dsa_detail=(
                        student_data.certification_dsa_detail
                        if certification_type == CertificationTypeEnum.DSA
                        else None
                    ),
                    mandatory_psych_meetings_acknowledged=(
                        student_data.mandatory_psych_meetings_acknowledged
                    ),
                )
            )

            for enrollment_data in student_data.school_enrollments:
                db.add(
                    SchoolEnrollment(
                        start_year=enrollment_data.start_year,
                        grade=GRADE_BY_ROMAN_NUMERAL.get(
                            enrollment_data.school_class,
                            _DEFAULT_GRADE,
                        ),
                        student_tax_code=person.tax_code,
                        study_program_id=enrollment_data.study_program_id,
                        school_id=enrollment_data.school_id,
                    )
                )

        if _ROLE_COURSE_PARTICIPANT in roles and payload.course_participant_data:
            course_participant_data = payload.course_participant_data

            db.add(
                CourseParticipant(
                    tax_code=person.tax_code,
                    medical_certificate_expiration=(
                        course_participant_data.medical_certificate_expiration
                    ),
                    course_type=CourseTypeEnum(course_participant_data.course_type),
                )
            )

        if payload.psychological_support_data:
            db.add(
                PsychologicalSupport(
                    tax_code=person.tax_code,
                    start_date=payload.psychological_support_data.start_date,
                )
            )

        needs_staff = any(role in roles for role in _STAFF_ROLES)

        if needs_staff and payload.staff_data:
            staff_data = payload.staff_data

            staff = Staff(
                tax_code=person.tax_code,
                collaboration_type=CollaborationTypeEnum(
                    staff_data.collaboration_type
                ),
                iban=staff_data.iban or None,
            )
            db.add(staff)

            if _ROLE_ADMIN in roles and payload.admin_data:
                admin_role = AdministratorRoleEnum(payload.admin_data.role)

                RoleService.assert_collaboration_type_consistent_with_admin_role(
                    admin_role, staff.collaboration_type
                )

                db.add(
                    Administrator(
                        tax_code=person.tax_code,
                        role=admin_role,
                        other_role=(
                            payload.admin_data.other_role
                            if admin_role == AdministratorRoleEnum.OTHER
                            else None
                        ),
                    )
                )

            if _ROLE_PSYCHOLOGIST in roles:
                db.add(Psychologist(tax_code=person.tax_code))

            if _ROLE_TEACHER in roles and payload.teacher_data:
                teacher_data = payload.teacher_data

                db.add(
                    Teacher(
                        tax_code=person.tax_code,
                        is_high_school_student=teacher_data.is_high_school_student,
                        school_education=teacher_data.school_education,
                        university_education=teacher_data.university_education,
                    )
                )

                for competence_data in teacher_data.competences:
                    for study_program_id in competence_data.study_program_ids:
                        db.add(
                            TeachingCompetence(
                                teacher_tax_code=person.tax_code,
                                association_subject_id=competence_data.subject_id,
                                study_program_id=study_program_id,
                            )
                        )

                await _add_teacher_services(
                    db,
                    person.tax_code,
                    teacher_data.service_names,
                )

    for minor in payload.relationships.minors_tax_codes:
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

    for parent_item in payload.relationships.parents_tax_codes:
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

    await db.commit()
    await db.refresh(person)

    return person