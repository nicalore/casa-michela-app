from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

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
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.student import CertificationTypeEnum, Student
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence
from app.schemas.person_wizard import PersonWizardPayload


async def create_person_from_wizard(db: AsyncSession, payload: PersonWizardPayload) -> Person:
    # Verifica esistenza
    existing_person = await db.get(Person, payload.general_data.tax_code)

    if existing_person:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Una persona con questo codice fiscale è già presente nel sistema."
        )

    roles = payload.roles

    if "PSICOLOGO" in roles and payload.psychological_support_data is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uno Psicologo non può essere iscritto al servizio di sostegno psicologico."
        )

    person = Person(
        tax_code=payload.general_data.tax_code,
        first_name=payload.general_data.first_name,
        last_name=payload.general_data.last_name,
        gender=payload.general_data.gender,
        birth_date=payload.general_data.birth_date,
        birth_city=payload.general_data.birth_city,
        birth_nation=payload.general_data.birth_nation,
        birth_province=payload.general_data.birth_province,
        residence_type=payload.general_data.residence_type,
        residence_address=payload.general_data.residence_address,
        residence_street_number=payload.general_data.residence_street_number,
        residence_city=payload.general_data.residence_city,
        residence_province=payload.general_data.residence_province,
        postal_code=payload.general_data.postal_code,
        email=payload.general_data.email,
        phone=payload.general_data.phone,
    )

    db.add(person)

    if "GENITORE" in roles:
        parent = Parent(tax_code=person.tax_code)
        db.add(parent)

    needs_member = any(r in roles for r in ["ASSOCIATO", "STUDENTE", "CORSISTA", "DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])

    if needs_member:
        member = Member(tax_code=person.tax_code)
        db.add(member)

        if payload.member_data:
            md = payload.member_data
            payment_method_val = (
                PaymentMethodEnum(md.payment_method) if md.payment_method else None
            )

            member.payment_method = payment_method_val
            member.payment_method_other = (
                md.payment_method_other if payment_method_val == PaymentMethodEnum.OTHER else None
            )
            member.statute_acknowledged = md.statute_acknowledged
            member.regulation_acknowledged = md.regulation_acknowledged
            member.video_surveillance_acknowledged = md.video_surveillance_acknowledged
            member.special_category_data_consent = md.special_category_data_consent
            member.newsletter_consent = md.newsletter_consent
            member.consents_signed_at = md.consents_signed_at
            member.emergency_contact_name = md.emergency_contact_name
            member.emergency_contact_phone = md.emergency_contact_phone
            member.allergies_notes = md.allergies_notes
            member.medications_notes = md.medications_notes

            for membership_data in md.memberships:
                membership = Membership(
                    member_tax_code=person.tax_code,
                    year=membership_data.year,
                    start_date=membership_data.start_date,
                    end_date=membership_data.end_date,
                    renewal_period_days=membership_data.renewal_period_days,
                    revocation=membership_data.revocation,
                )
                db.add(membership)

        if "STUDENTE" in roles and payload.student_data:
            s_data = payload.student_data
            certification_type_val = (
                CertificationTypeEnum(s_data.certification_type) if s_data.certification_type else None
            )

            student = Student(
                tax_code=person.tax_code,
                authorized_early_exit=s_data.authorized_early_exit,
                certification_type=certification_type_val,
                certification_other_detail=(
                    s_data.certification_other_detail
                    if certification_type_val == CertificationTypeEnum.OTHER
                    else None
                ),
                mandatory_psych_meetings_acknowledged=s_data.mandatory_psych_meetings_acknowledged,
            )
            db.add(student)

            grade_map = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5}

            for enrollment_data in s_data.school_enrollments:
                numeric_grade = grade_map.get(enrollment_data.school_class, 1)

                school_enrollment = SchoolEnrollment(
                    start_year=enrollment_data.start_year,
                    grade=numeric_grade,
                    student_tax_code=person.tax_code,
                    study_program_id=enrollment_data.study_program_id,
                    school_id=enrollment_data.school_id
                )
                db.add(school_enrollment)

        if "CORSISTA" in roles and payload.course_participant_data:
            corsista = CourseParticipant(
                tax_code=person.tax_code,
                medical_certificate_expiration=payload.course_participant_data.medical_certificate_expiration,
                course_type=CourseTypeEnum(payload.course_participant_data.course_type)
            )
            db.add(corsista)

        if payload.psychological_support_data:
            support = PsychologicalSupport(
                tax_code=person.tax_code,
                start_date=payload.psychological_support_data.start_date,
            )
            db.add(support)

        needs_staff = any(r in roles for r in ["DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])

        if needs_staff and payload.staff_data:
            # Conversione esplicita per staff
            staff = Staff(
                tax_code=person.tax_code,
                collaboration_type=CollaborationTypeEnum(payload.staff_data.collaboration_type),
                iban=payload.staff_data.iban if payload.staff_data.iban else None
            )
            db.add(staff)

            if "AMMINISTRATORE" in roles and payload.admin_data:
                # Conversione esplicita per ruolo admin
                role_val = AdministratorRoleEnum(payload.admin_data.role)
                admin = Administrator(
                    tax_code=person.tax_code,
                    role=role_val,
                    other_role=payload.admin_data.other_role if role_val == AdministratorRoleEnum.OTHER else None
                )
                db.add(admin)

            if "PSICOLOGO" in roles:
                psicologo = Psychologist(tax_code=person.tax_code)
                db.add(psicologo)

            if "DOCENTE" in roles and payload.teacher_data:
                teacher = Teacher(
                    tax_code=person.tax_code,
                    school_education=payload.teacher_data.school_education,
                    university_education=payload.teacher_data.university_education
                )
                db.add(teacher)

                for comp in payload.teacher_data.competences:
                    for prog_id in comp.study_program_ids:
                        competence = TeachingCompetence(
                            teacher_tax_code=person.tax_code,
                            association_subject_id=comp.subject_id,
                            study_program_id=prog_id
                        )
                        db.add(competence)

    for minor in payload.relationships.minors_tax_codes:
        rel = ParentalResponsibility(
            parent_tax_code=person.tax_code,
            child_tax_code=minor.tax_code,
            authorized_pickup=minor.authorized_pickup,
            pickup_restriction_reason=(
                minor.pickup_restriction_reason if not minor.authorized_pickup else None
            ),
        )
        db.add(rel)

    for parent_item in payload.relationships.parents_tax_codes:
        rel = ParentalResponsibility(
            parent_tax_code=parent_item.tax_code,
            child_tax_code=person.tax_code,
            authorized_pickup=parent_item.authorized_pickup,
            pickup_restriction_reason=(
                parent_item.pickup_restriction_reason if not parent_item.authorized_pickup else None
            ),
        )
        db.add(rel)

    await db.commit()
    await db.refresh(person)

    return person