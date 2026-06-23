from datetime import date

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator import Administrator
from app.models.course_participant import CourseParticipant
from app.models.member import Member
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.psychologist import Psychologist
from app.models.school_enrollment import SchoolEnrollment
from app.models.staff import Staff
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence
from app.schemas.person_wizard import PersonWizardPayload


async def create_person_from_wizard(db: AsyncSession, payload: PersonWizardPayload) -> Person:
    existing_person = await db.get(Person, payload.general_data.tax_code)
    
    if existing_person:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Una persona con questo codice fiscale è già presente a sistema."
        )

    person = Person(
        tax_code=payload.general_data.tax_code,
        first_name=payload.general_data.first_name,
        last_name=payload.general_data.last_name,
        gender=payload.general_data.gender,
        birth_date=payload.general_data.birth_date,
        birth_city=payload.general_data.birth_city,
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

    roles = payload.roles

    if "GENITORE" in roles:
        parent = Parent(tax_code=person.tax_code)
        db.add(parent)

    needs_member = any(r in roles for r in ["ASSOCIATO", "STUDENTE", "CORSISTA", "DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])
    
    if needs_member:
        member = Member(tax_code=person.tax_code)
        db.add(member)

        if "STUDENTE" in roles and payload.student_data:
            student = Student(
                tax_code=person.tax_code,
                authorized_early_exit=payload.student_data.authorized_early_exit
            )
            db.add(student)

            today      = date.today()
            start_year = today.year - 1 if today.month < 9 else today.year
            grade_map  = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5}
            
            numeric_grade = grade_map.get(payload.student_data.school_class, 1)

            school_enrollment = SchoolEnrollment(
                start_year=start_year,
                grade=numeric_grade,
                student_tax_code=person.tax_code,
                study_program_id=payload.student_data.study_program_id,
                school_mechanographic_code=payload.student_data.school_mechanographic_code
            )
            db.add(school_enrollment)

        if "CORSISTA" in roles and payload.course_participant_data:
            corsista = CourseParticipant(
                tax_code=person.tax_code,
                medical_certificate_expiration=payload.course_participant_data.medical_certificate_expiration,
                course_type=payload.course_participant_data.course_type
            )
            db.add(corsista)

        needs_staff = any(r in roles for r in ["DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])
        
        if needs_staff and payload.staff_data:
            staff = Staff(
                tax_code=person.tax_code,
                collaboration_type=payload.staff_data.collaboration_type,
                iban=payload.staff_data.iban if payload.staff_data.iban else None
            )
            db.add(staff)

            if "AMMINISTRATORE" in roles and payload.admin_data:
                admin = Administrator(
                    tax_code=person.tax_code,
                    role=payload.admin_data.role,
                    other_role=payload.admin_data.other_role if payload.admin_data.role == "OTHER" else None
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

    for minor_code in payload.relationships.minors_tax_codes:
        rel = ParentalResponsibility(
            parent_tax_code=person.tax_code,
            child_tax_code=minor_code
        )
        db.add(rel)

    for parent_code in payload.relationships.parents_tax_codes:
        rel = ParentalResponsibility(
            parent_tax_code=parent_code,
            child_tax_code=person.tax_code
        )
        db.add(rel)

    await db.commit()
    await db.refresh(person)
    
    return person