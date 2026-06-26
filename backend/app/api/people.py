import os
import shutil
from datetime import date, datetime

import resend
from fastapi import APIRouter, File, HTTPException, UploadFile, status
from sqlalchemy import select, delete, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import joinedload

from app.core.config import settings
from app.schemas.person_wizard import PersonWizardPayload
from app.services.person_wizard_service import create_person_from_wizard

from ..models.administrator import Administrator, AdministratorRoleEnum
from ..models.course_participant import CourseParticipant
from ..models.member import Member
from ..models.membership import Membership, MembershipRevocationEnum
from ..models.parent import Parent
from ..models.parental_responsibility import ParentalResponsibility
from ..models.person import GenderEnum, Person
from ..models.psychologist import Psychologist
from ..models.school_enrollment import SchoolEnrollment
from ..models.school_study_program import SchoolStudyProgram
from ..models.staff import CollaborationTypeEnum, Staff
from ..models.student import Student
from ..models.teacher import Teacher
from ..models.teaching_competence import TeachingCompetence
from ..schemas.person import (
    ChildInfoResponse,
    MembershipResponse,
    ParentInfoResponse,
    ParentUpdatePayload,
    PersonMembershipsUpdate,
    PersonResponse,
    PersonSchoolEnrollmentsUpdate,
    PersonTeacherCompetencesUpdate,
    PersonUpdatePayload,
    RevokeMembershipPayload,
    SchoolEnrollmentResponse,
    TeacherSubjectResponse,
)
from .dependencies import DbSession

router = APIRouter(prefix="/people", tags=["people"])

resend.api_key = settings.resend_api_key

def _translate_collaboration_type(collab_type: str | None) -> str | None:
    if not collab_type:
        return None
    if collab_type == "VOLUNTEER":
        return "Volontario"
    if collab_type == "PAID":
        return "Retribuito"
    if collab_type == "PCTO":
        return "PCTO"
    return collab_type

def _translate_education_level(level: str | None) -> str | None:
    if not level:
        return None
    if level == "PRIMARY_SCHOOL":
        return "Scuola Primaria"
    if level == "MIDDLE_SCHOOL":
        return "Secondaria I grado"
    if level == "HIGH_SCHOOL":
        return "Secondaria II grado"
    return level

def _roman_numeral(num: int) -> str:
    roman_map = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V'}
    return roman_map.get(num, str(num))

def _map_person_to_response(p: Person) -> PersonResponse:
    roles                   = []
    is_active_collab        = None
    enrollment_year         = None
    collab_type_translated  = None
    is_med_cert_valid       = None
    course_type             = None
    education_level         = None
    school_name             = None
    school_class            = None
    study_program           = None
    early_exit              = None
    taught_subjects_list    = []
    memberships_list        = []
    school_enrollments_list = []
    parents_list            = []
    children_list           = []
    teacher_subjects_list   = []
    
    iban                           = None
    admin_role                     = None
    admin_other_role               = None
    school_education               = None
    university_education           = None
    medical_certificate_expiration = None
    
    if p.parent_profile is not None:
        roles.append('Genitore')
        for rel in p.parent_profile.children_relationships:
            child_person = rel.child
            if child_person:
                c_school_name = None
                c_school_class = None
                c_study_program = None
                if child_person.member_profile and child_person.member_profile.student_profile:
                    c_student = child_person.member_profile.student_profile
                    if c_student.school_enrollments:
                        c_latest = max(c_student.school_enrollments, key=lambda e: e.start_year)
                        c_school_class = _roman_numeral(c_latest.grade)
                        if c_latest.school_study_program:
                            if c_latest.school_study_program.school:
                                c_school_name = c_latest.school_study_program.school.name
                            if c_latest.school_study_program.study_program:
                                c_study_program = c_latest.school_study_program.study_program.name

                children_list.append(ChildInfoResponse(
                    fiscal_code=child_person.tax_code,
                    first_name=child_person.first_name,
                    last_name=child_person.last_name,
                    gender=child_person.gender,
                    email=child_person.email,
                    phone=child_person.phone,
                    birth_city=child_person.birth_city,
                    birth_province=child_person.birth_province,
                    residence_type=child_person.residence_type,
                    residence_address=child_person.residence_address,
                    residence_street_number=child_person.residence_street_number,
                    residence_province=child_person.residence_province,
                    postal_code=child_person.postal_code,
                    city=child_person.residence_city,
                    birth_date=child_person.birth_date,
                    school_name=c_school_name,
                    school_class=c_school_class,
                    study_program=c_study_program
                ))
        
    if p.parental_relationships:
        for rel in p.parental_relationships:
            parent_person = rel.parent.person
            if parent_person:
                parents_list.append(ParentInfoResponse(
                    fiscal_code=parent_person.tax_code,
                    first_name=parent_person.first_name,
                    last_name=parent_person.last_name,
                    gender=parent_person.gender,
                    email=parent_person.email,
                    phone=parent_person.phone,
                    birth_city=parent_person.birth_city,
                    birth_province=parent_person.birth_province,
                    residence_type=parent_person.residence_type,
                    residence_address=parent_person.residence_address,
                    residence_street_number=parent_person.residence_street_number,
                    residence_province=parent_person.residence_province,
                    postal_code=parent_person.postal_code,
                    city=parent_person.residence_city,
                    birth_date=parent_person.birth_date
                ))
        
    member = p.member_profile
    
    if member is not None:
        roles.append('Associato')
        is_active_collab = member.collaborating_active
        
        if member.memberships:
            first_membership = min(member.memberships, key=lambda m: m.year)
            enrollment_year  = str(first_membership.year)
            
            for m in member.memberships:
                memberships_list.append(MembershipResponse(
                    year=m.year,
                    start_date=m.start_date,
                    end_date=m.end_date,
                    renewal_period_days=m.renewal_period_days,
                    revocation=m.revocation
                ))

        if member.course_participant_profile is not None:
            roles.append('Corsista')
            course_profile = member.course_participant_profile
            course_type    = course_profile.course_type
            medical_certificate_expiration = course_profile.medical_certificate_expiration
            
            if course_profile.medical_certificate_expiration:
                is_med_cert_valid = course_profile.medical_certificate_expiration >= date.today()
            else:
                is_med_cert_valid = False

        if member.student_profile is not None:
            roles.append('Studente')
            student    = member.student_profile
            early_exit = student.authorized_early_exit
            
            if student.school_enrollments:
                for e in student.school_enrollments:
                    ssp = e.school_study_program
                    if ssp and ssp.school and ssp.study_program:
                        school_enrollments_list.append(SchoolEnrollmentResponse(
                            start_year=e.start_year,
                            grade=e.grade,
                            school_name=ssp.school.name,
                            school_mechanographic_code=ssp.school_mechanographic_code,
                            study_program_name=ssp.study_program.name,
                            study_program_id=ssp.study_program_id,
                            education_level=_translate_education_level(ssp.study_program.level) or ""
                        ))

                latest_enrollment = max(student.school_enrollments, key=lambda e: e.start_year)
                school_class      = _roman_numeral(latest_enrollment.grade)
                
                ssp = latest_enrollment.school_study_program
                if ssp is not None:
                    if ssp.school:
                        school_name = ssp.school.name
                    if ssp.study_program:
                        study_program   = ssp.study_program.name
                        education_level = _translate_education_level(ssp.study_program.level)

        if member.staff_profile is not None:
            staff                  = member.staff_profile
            collab_type_translated = _translate_collaboration_type(staff.collaboration_type)
            iban                   = staff.iban
            
            if staff.administrator_profile is not None:
                roles.append('Amministratore')
                admin_role       = staff.administrator_profile.role
                admin_other_role = staff.administrator_profile.other_role
                
            if staff.teacher_profile is not None:
                roles.append('Docente')
                school_education     = staff.teacher_profile.school_education
                university_education = staff.teacher_profile.university_education
                subjects_set         = set()
                
                teacher_subjects_dict = {}
                
                for comp in staff.teacher_profile.teaching_competences:
                    if comp.association_subject:
                        subjects_set.add(comp.association_subject.name)
                        
                        if comp.study_program:
                            s_id = comp.association_subject.id
                            if s_id not in teacher_subjects_dict:
                                teacher_subjects_dict[s_id] = {
                                    "subject_id":        s_id,
                                    "subject_name":      comp.association_subject.name,
                                    "subject_area":      comp.association_subject.area,
                                    "study_program_ids": [],
                                    "study_programs":    []
                                }
                            teacher_subjects_dict[s_id]["study_program_ids"].append(comp.study_program.id)
                            teacher_subjects_dict[s_id]["study_programs"].append(comp.study_program.name)
                        
                taught_subjects_list = sorted(list(subjects_set))
                teacher_subjects_list = [TeacherSubjectResponse(**data) for data in teacher_subjects_dict.values()]
                
            if staff.psychologist_profile is not None:
                roles.append('Psicologo')

    children_count = len(p.parent_profile.children_relationships) if p.parent_profile else None
    
    return PersonResponse(
        fiscal_code=p.tax_code,
        first_name=p.first_name,
        last_name=p.last_name,
        roles=roles,
        created_at=getattr(p, 'created_at', datetime.now()),
        profile_image_url=p.profile_image_url, 
        gender=p.gender,
        email=p.email,
        phone=p.phone,
        birth_city=p.birth_city,
        birth_province=p.birth_province,
        residence_type=p.residence_type,
        residence_address=p.residence_address,
        residence_street_number=p.residence_street_number,
        residence_province=p.residence_province,
        postal_code=p.postal_code,
        city=p.residence_city,
        birth_date=p.birth_date,
        children_count=children_count,
        is_active_collaborator=is_active_collab,
        enrollment_year=enrollment_year,
        collaboration_type=collab_type_translated,
        course_type=course_type,
        is_medical_certificate_valid=is_med_cert_valid,
        education_level=education_level,
        school_name=school_name,
        school_class=school_class,
        study_program=study_program,
        early_exit=early_exit,
        taught_subjects=taught_subjects_list,
        memberships=memberships_list if memberships_list else None,
        school_enrollments=school_enrollments_list if school_enrollments_list else None,
        parents=parents_list if parents_list else None,
        children=children_list if children_list else None,
        teacher_subjects=teacher_subjects_list if teacher_subjects_list else None,
        iban=iban,
        admin_role=admin_role,
        admin_other_role=admin_other_role,
        school_education=school_education,
        university_education=university_education,
        medical_certificate_expiration=medical_certificate_expiration
    )


@router.get("/", response_model=list[PersonResponse])
async def get_people(db: DbSession):
    stmt = (
        select(Person)
        .options(
            joinedload(Person.account),
            joinedload(Person.parent_profile).joinedload(Parent.children_relationships).joinedload(ParentalResponsibility.child).joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments).joinedload(SchoolEnrollment.school_study_program).joinedload(SchoolStudyProgram.school),
            joinedload(Person.parent_profile).joinedload(Parent.children_relationships).joinedload(ParentalResponsibility.child).joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments).joinedload(SchoolEnrollment.school_study_program).joinedload(SchoolStudyProgram.study_program),
            joinedload(Person.parental_relationships).joinedload(ParentalResponsibility.parent).joinedload(Parent.person),
            joinedload(Person.member_profile).joinedload(Member.memberships),
            joinedload(Person.member_profile).joinedload(Member.course_participant_profile),
            joinedload(Person.member_profile)
                .joinedload(Member.student_profile)
                .joinedload(Student.school_enrollments) 
                .joinedload(SchoolEnrollment.school_study_program)
                .joinedload(SchoolStudyProgram.school),
            joinedload(Person.member_profile)
                .joinedload(Member.student_profile)
                .joinedload(Student.school_enrollments) 
                .joinedload(SchoolEnrollment.school_study_program)
                .joinedload(SchoolStudyProgram.study_program),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.administrator_profile),
            joinedload(Person.member_profile)
                .joinedload(Member.staff_profile)
                .joinedload(Staff.teacher_profile)
                .joinedload(Teacher.teaching_competences)
                .joinedload(TeachingCompetence.association_subject),
            joinedload(Person.member_profile)
                .joinedload(Member.staff_profile)
                .joinedload(Staff.teacher_profile)
                .joinedload(Teacher.teaching_competences)
                .joinedload(TeachingCompetence.study_program),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.psychologist_profile),
        )
    )
    
    result = await db.execute(stmt)
    people = result.unique().scalars().all()
    
    return [_map_person_to_response(p) for p in people]


@router.get("/{tax_code}", response_model=PersonResponse)
async def get_person(tax_code: str, db: DbSession):
    stmt = (
        select(Person)
        .options(
            joinedload(Person.account),
            joinedload(Person.parent_profile).joinedload(Parent.children_relationships).joinedload(ParentalResponsibility.child).joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments).joinedload(SchoolEnrollment.school_study_program).joinedload(SchoolStudyProgram.school),
            joinedload(Person.parent_profile).joinedload(Parent.children_relationships).joinedload(ParentalResponsibility.child).joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments).joinedload(SchoolEnrollment.school_study_program).joinedload(SchoolStudyProgram.study_program),
            joinedload(Person.parental_relationships).joinedload(ParentalResponsibility.parent).joinedload(Parent.person),
            joinedload(Person.member_profile).joinedload(Member.memberships),
            joinedload(Person.member_profile).joinedload(Member.course_participant_profile),
            joinedload(Person.member_profile)
                .joinedload(Member.student_profile)
                .joinedload(Student.school_enrollments) 
                .joinedload(SchoolEnrollment.school_study_program)
                .joinedload(SchoolStudyProgram.school),
            joinedload(Person.member_profile)
                .joinedload(Member.student_profile)
                .joinedload(Student.school_enrollments) 
                .joinedload(SchoolEnrollment.school_study_program)
                .joinedload(SchoolStudyProgram.study_program),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.administrator_profile),
            joinedload(Person.member_profile)
                .joinedload(Member.staff_profile)
                .joinedload(Staff.teacher_profile)
                .joinedload(Teacher.teaching_competences)
                .joinedload(TeachingCompetence.association_subject),
            joinedload(Person.member_profile)
                .joinedload(Member.staff_profile)
                .joinedload(Staff.teacher_profile)
                .joinedload(Teacher.teaching_competences)
                .joinedload(TeachingCompetence.study_program),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.psychologist_profile),
        )
        .where(Person.tax_code == tax_code.upper())
    )
    
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    return _map_person_to_response(person)

@router.put("/{tax_code}", status_code=status.HTTP_200_OK)
async def update_person(tax_code: str, payload: PersonUpdatePayload, db: DbSession):
    stmt = (
        select(Person)
        .options(
            joinedload(Person.member_profile).joinedload(Member.course_participant_profile),
            joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.administrator_profile),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.teacher_profile).joinedload(Teacher.teaching_competences),
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.psychologist_profile),
            joinedload(Person.member_profile).joinedload(Member.memberships),
            joinedload(Person.parent_profile),
            joinedload(Person.parental_relationships),
        )
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    data = payload.general_data
    
    new_tax_code = data.tax_code.upper()
    if new_tax_code != person.tax_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La modifica del Codice Fiscale non è consentita per preservare l'integrità dei dati storici."
        )
    
    person.first_name              = data.first_name
    person.last_name               = data.last_name
    person.gender                  = GenderEnum(data.gender)
    person.birth_date              = data.birth_date
    person.birth_city              = data.birth_city
    person.birth_province          = data.birth_province
    person.residence_type          = data.residence_type
    person.residence_address       = data.residence_address
    person.residence_street_number = data.residence_street_number
    person.residence_city          = data.residence_city
    person.residence_province      = data.residence_province
    person.postal_code             = data.postal_code
    person.email                   = data.email
    person.phone                   = data.phone

    if payload.relationships is not None:
        stmt_del = delete(ParentalResponsibility).where(
            or_(
                ParentalResponsibility.parent_tax_code == person.tax_code,
                ParentalResponsibility.child_tax_code == person.tax_code
            )
        )
        await db.execute(stmt_del)
        await db.flush()
        
        for minor_code in payload.relationships.minors_tax_codes:
            if minor_code != person.tax_code:
                db.add(ParentalResponsibility(parent_tax_code=person.tax_code, child_tax_code=minor_code))
                
        for parent_code in payload.relationships.parents_tax_codes:
            if parent_code != person.tax_code:
                db.add(ParentalResponsibility(parent_tax_code=parent_code, child_tax_code=person.tax_code))
        await db.flush()
    
    roles = [r.upper() for r in payload.roles]

    if "GENITORE" in roles:
        if not person.parent_profile:
            db.add(Parent(tax_code=person.tax_code))
    else:
        if person.parent_profile:
            await db.delete(person.parent_profile)

    needs_member = any(r in roles for r in ["ASSOCIATO", "STUDENTE", "CORSISTA", "DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])
    if needs_member:
        if not person.member_profile:
            person.member_profile = Member(tax_code=person.tax_code)
            db.add(person.member_profile)
            
        member = person.member_profile

        if "STUDENTE" in roles and payload.student_data:
            s_data = payload.student_data
            if not member.student_profile:
                member.student_profile = Student(tax_code=person.tax_code, authorized_early_exit=s_data.authorized_early_exit)
                db.add(member.student_profile)
            else:
                member.student_profile.authorized_early_exit = s_data.authorized_early_exit
            
            #Comment Aggiorna o crea l'iscrizione scolastica corrente
            today = date.today()
            start_year = today.year - 1 if today.month < 9 else today.year
            grade_map  = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5}
            numeric_grade = grade_map.get(s_data.school_class, 1)

            latest_enrollment = None
            if member.student_profile.school_enrollments:
                latest_enrollment = max(member.student_profile.school_enrollments, key=lambda e: e.start_year)

            if latest_enrollment and latest_enrollment.start_year == start_year:
                latest_enrollment.grade = numeric_grade
                latest_enrollment.study_program_id = s_data.study_program_id
                latest_enrollment.school_mechanographic_code = s_data.school_mechanographic_code
            else:
                new_enrollment = SchoolEnrollment(
                    student_tax_code=person.tax_code,
                    start_year=start_year,
                    grade=numeric_grade,
                    study_program_id=s_data.study_program_id,
                    school_mechanographic_code=s_data.school_mechanographic_code
                )
                db.add(new_enrollment)
        else:
            if member.student_profile:
                for e in list(member.student_profile.school_enrollments):
                    await db.delete(e)
                await db.delete(member.student_profile)

        if "CORSISTA" in roles and payload.course_participant_data:
            cp_data = payload.course_participant_data
            if not member.course_participant_profile:
                member.course_participant_profile = CourseParticipant(
                    tax_code=person.tax_code,
                    medical_certificate_expiration=cp_data.medical_certificate_expiration,
                    course_type=cp_data.course_type
                )
                db.add(member.course_participant_profile)
            else:
                member.course_participant_profile.medical_certificate_expiration = cp_data.medical_certificate_expiration
                member.course_participant_profile.course_type = cp_data.course_type
        else:
            if member.course_participant_profile:
                await db.delete(member.course_participant_profile)

        needs_staff = any(r in roles for r in ["DOCENTE", "AMMINISTRATORE", "PSICOLOGO"])
        if needs_staff and payload.staff_data:
            st_data = payload.staff_data
            collab_enum = CollaborationTypeEnum(st_data.collaboration_type)
            if not member.staff_profile:
                member.staff_profile = Staff(
                    tax_code=person.tax_code,
                    collaboration_type=collab_enum,
                    iban=st_data.iban if st_data.iban else None
                )
                db.add(member.staff_profile)
            else:
                member.staff_profile.collaboration_type = collab_enum
                member.staff_profile.iban = st_data.iban if st_data.iban else None
                
            staff = member.staff_profile

            if "AMMINISTRATORE" in roles and payload.admin_data:
                ad_data = payload.admin_data
                role_enum = AdministratorRoleEnum(ad_data.role)
                if not staff.administrator_profile:
                    staff.administrator_profile = Administrator(
                        tax_code=person.tax_code,
                        role=role_enum,
                        other_role=ad_data.other_role if role_enum == AdministratorRoleEnum.OTHER else None
                    )
                    db.add(staff.administrator_profile)
                else:
                    staff.administrator_profile.role = role_enum
                    staff.administrator_profile.other_role = ad_data.other_role if role_enum == AdministratorRoleEnum.OTHER else None
            else:
                if staff.administrator_profile:
                    await db.delete(staff.administrator_profile)

            if "DOCENTE" in roles and payload.teacher_data:
                te_data = payload.teacher_data
                if not staff.teacher_profile:
                    staff.teacher_profile = Teacher(
                        tax_code=person.tax_code,
                        school_education=te_data.school_education,
                        university_education=te_data.university_education
                    )
                    db.add(staff.teacher_profile)
                else:
                    staff.teacher_profile.school_education = te_data.school_education
                    staff.teacher_profile.university_education = te_data.university_education
                
                if te_data.competences is not None:
                    for comp in list(staff.teacher_profile.teaching_competences):
                        await db.delete(comp)
                    await db.flush()
                    staff.teacher_profile.teaching_competences.clear()
                    
                    for comp_data in te_data.competences:
                        for sp_id in comp_data.study_program_ids:
                            new_comp = TeachingCompetence(
                                teacher_tax_code=person.tax_code,
                                association_subject_id=comp_data.subject_id, 
                                study_program_id=sp_id
                            )
                            db.add(new_comp)
            else:
                if staff.teacher_profile:
                    for comp in list(staff.teacher_profile.teaching_competences):
                        await db.delete(comp)
                    await db.delete(staff.teacher_profile)

            if "PSICOLOGO" in roles:
                if not staff.psychologist_profile:
                    db.add(Psychologist(tax_code=person.tax_code))
            else:
                if staff.psychologist_profile:
                    await db.delete(staff.psychologist_profile)
        else:
            if member.staff_profile:
                staff = member.staff_profile
                if staff.administrator_profile:
                    await db.delete(staff.administrator_profile)
                if staff.teacher_profile:
                    for comp in list(staff.teacher_profile.teaching_competences):
                        await db.delete(comp)
                    await db.delete(staff.teacher_profile)
                if staff.psychologist_profile:
                    await db.delete(staff.psychologist_profile)
                await db.delete(staff)
    else:
        if person.member_profile:
            m = person.member_profile
            if m.student_profile:
                for e in list(m.student_profile.school_enrollments):
                    await db.delete(e)
                await db.delete(m.student_profile)
            if m.course_participant_profile:
                await db.delete(m.course_participant_profile)
            if m.staff_profile:
                staff = m.staff_profile
                if staff.administrator_profile:
                    await db.delete(staff.administrator_profile)
                if staff.teacher_profile:
                    for comp in list(staff.teacher_profile.teaching_competences):
                        await db.delete(comp)
                    await db.delete(staff.teacher_profile)
                if staff.psychologist_profile:
                    await db.delete(staff.psychologist_profile)
                await db.delete(staff)
            for memb in list(m.memberships):
                await db.delete(memb)
            await db.delete(m)

    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        error_msg = str(e).lower()
        if "uq_administrator_president" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Esiste già un Presidente configurato all'interno del sistema."
            )
        if "uq_administrator_vice_president" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Esiste già un Vice Presidente configurato all'interno del sistema."
            )
        if "uq_administrator_treasurer" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Esiste già un Tesoriere configurato all'interno del sistema."
            )
            
        if "unique constraint" in error_msg or "duplicate key" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="L'email o il numero di telefono risultano già associati a un'altra anagrafica nel sistema."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail="Errore di validazione dei vincoli del database."
            )
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Errore interno del server durante l'aggiornamento: {str(e)}"
        )

    return {"message": "Anagrafica aggiornata con successo", "new_tax_code": person.tax_code}

@router.put("/{tax_code}/school-enrollments", status_code=status.HTTP_200_OK)
async def update_person_school_enrollments(tax_code: str, payload: PersonSchoolEnrollmentsUpdate, db: DbSession):
    if not payload.enrollments:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossibile salvare lo storico scolastico vuoto. È necessaria almeno un'iscrizione."
        )

    stmt = (
        select(Person)
        .options(joinedload(Person.member_profile).joinedload(Member.student_profile).joinedload(Student.school_enrollments))
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    member = person.member_profile
    if not member or not member.student_profile:
        raise HTTPException(status_code=400, detail="L'utente non possiede un profilo da studente.")
        
    years = [e.start_year for e in payload.enrollments]
    if len(years) != len(set(years)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non è possibile registrare più di un'iscrizione scolastica per lo stesso anno."
        )

    student = member.student_profile
    
    for e in list(student.school_enrollments):
        await db.delete(e)
        
    await db.flush() 
    student.school_enrollments.clear()
    
    for e_data in payload.enrollments:
        new_e = SchoolEnrollment(
            student_tax_code=person.tax_code,
            start_year=e_data.start_year,
            grade=e_data.grade,
            study_program_id=e_data.study_program_id,
            school_mechanographic_code=e_data.school_mechanographic_code
        )
        db.add(new_e)
        
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Errore durante l'aggiornamento delle iscrizioni scolastiche: {str(e)}"
        )
        
    return {"message": "Iscrizioni scolastiche aggiornate con successo"}


@router.post("/{tax_code}/parents", status_code=status.HTTP_200_OK)
async def add_parental_responsibility(tax_code: str, payload: ParentUpdatePayload, db: DbSession):
    stmt_child = select(Person).where(Person.tax_code == tax_code.upper())
    child      = (await db.execute(stmt_child)).scalar_one_or_none()
    if not child:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    stmt_parent = (
        select(Person)
        .options(joinedload(Person.parent_profile))
        .where(Person.tax_code == payload.parent_tax_code.upper())
    )
    parent = (await db.execute(stmt_parent)).scalar_one_or_none()
    
    if not parent or not parent.parent_profile:
        raise HTTPException(status_code=400, detail="Il soggetto selezionato non ha un profilo genitore.")
        
    stmt = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == tax_code.upper(),
        ParentalResponsibility.parent_tax_code == payload.parent_tax_code.upper()
    )
    if (await db.execute(stmt)).scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Questo genitore è già associato a questa persona.")
        
    stmt_count = select(ParentalResponsibility).where(ParentalResponsibility.child_tax_code == tax_code.upper())
    if len((await db.execute(stmt_count)).scalars().all()) >= 2:
        raise HTTPException(status_code=400, detail="Numero massimo di genitori (2) già raggiunto.")
        
    db.add(ParentalResponsibility(parent_tax_code=payload.parent_tax_code.upper(), child_tax_code=tax_code.upper()))
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
        
    return {"message": "Genitore aggiunto con successo"}


@router.put("/{tax_code}/parents/{old_parent_tax_code}", status_code=status.HTTP_200_OK)
async def update_parental_responsibility(tax_code: str, old_parent_tax_code: str, payload: ParentUpdatePayload, db: DbSession):
    stmt = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == tax_code.upper(),
        ParentalResponsibility.parent_tax_code == old_parent_tax_code.upper()
    )
    rel = (await db.execute(stmt)).scalar_one_or_none()
    if not rel:
        raise HTTPException(status_code=404, detail="Associazione genitoriale non trovata.")
        
    if payload.parent_tax_code.upper() == old_parent_tax_code.upper():
        return {"message": "Nessuna modifica effettuata"}
        
    stmt_new_parent = (
        select(Person)
        .options(joinedload(Person.parent_profile))
        .where(Person.tax_code == payload.parent_tax_code.upper())
    )
    new_parent = (await db.execute(stmt_new_parent)).scalar_one_or_none()
    
    if not new_parent or not new_parent.parent_profile:
        raise HTTPException(status_code=400, detail="Il nuovo soggetto selezionato non ha un profilo genitore.")
        
    stmt_check = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == tax_code.upper(),
        ParentalResponsibility.parent_tax_code == payload.parent_tax_code.upper()
    )
    if (await db.execute(stmt_check)).scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Il nuovo genitore è già associato a questa persona.")
        
    await db.delete(rel)
    db.add(ParentalResponsibility(parent_tax_code=payload.parent_tax_code.upper(), child_tax_code=tax_code.upper()))
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
        
    return {"message": "Genitore aggiornato con successo"}


@router.delete("/{tax_code}/parents/{parent_tax_code}", status_code=status.HTTP_200_OK)
async def delete_parental_responsibility(tax_code: str, parent_tax_code: str, db: DbSession):
    stmt = select(ParentalResponsibility).where(
        ParentalResponsibility.child_tax_code == tax_code.upper(),
        ParentalResponsibility.parent_tax_code == parent_tax_code.upper()
    )
    rel = (await db.execute(stmt)).scalar_one_or_none()
    if not rel:
        raise HTTPException(status_code=404, detail="Associazione genitoriale non trovata.")
        
    await db.delete(rel)
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
        
    return {"message": "Associazione rimossa con successo"}


@router.post("/{tax_code}/report-error", status_code=status.HTTP_200_OK)
async def report_person_error(tax_code: str, corrections: dict, db: DbSession):
    person = await db.get(Person, tax_code)
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")

    fields_html = ""
    for field, value in corrections.items():
        fields_html += f"""
        <div style="margin-bottom: 16px;">
            <p style="margin: 0 0 4px 0; font-weight: bold; color: #003C82;">{field}</p>
            <p style="margin: 0; padding: 12px; background-color: #F1F5F9; border-left: 4px solid #003C82; border-radius: 0 4px 4px 0;">
                {value}
            </p>
        </div>
        """

    html_content = f"""
    <div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; color: #333333; line-height: 1.6;">
        <div style="text-align: center; margin-bottom: 30px;">
            <img src="https://primary.jwwb.nl/public/y/k/w/temp-mfffkbfpkmjgalfrjfhx/logo-casamichela-1-high-bl0vca.png?enable-io=true&width=100" alt="Associazione Casa Michela" style="width: 120px; height: auto;" />
            <p style="margin-top: 10px; color: #003C82; font-weight: bold; font-size: 18px;">Associazione Casa Michela</p>
        </div>
        <h2 style="color: #003C82;">Segnalazione Errore Anagrafica</h2>
        <p>Ciao Nicolò,</p>
        <p>È stata inviata una richiesta di correzione per i dati anagrafici protetti di un utente all'interno del sistema gestionale.</p>
        
        <div style="background-color: #F8FAFC; padding: 20px; border-radius: 8px; border: 1px solid #E2E8F0; margin: 20px 0;">
            <p style="margin: 0 0 8px 0;"><strong>Soggetto interessato:</strong> {person.first_name} {person.last_name}</p>
            <p style="margin: 0;"><strong>Codice Fiscale Attuale:</strong> {person.tax_code}</p>
        </div>
        
        <h3 style="color: #003C82; margin-top: 30px; margin-bottom: 15px;">Correzioni e modifiche richieste:</h3>
        {fields_html}
        
        <p style="margin-top: 30px; font-size: 13px; color: #64748B;">Questa mail è stata generata automaticamente dall'applicazione a seguito della compilazione del modulo di segnalazione errore.</p>
    </div>
    """

    try:
        resend.Emails.send({
            "from": "Associazione Casa Michela <supporto@app.casamichela.it>",
            "to": "nicolo.calore@casamichela.it",
            "reply_to": "nicolo.calore@casamichela.it",
            "subject": f"Richiesta correzione anagrafica - {person.first_name} {person.last_name}",
            "html": html_content
        })
        return {"status": "success", "message": "Segnalazione inviata correttamente"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Impossibile inviare la mail tramite Resend: {str(e)}"
        )


@router.post("/wizard/", status_code=status.HTTP_201_CREATED)
async def wizard_create_person(payload: PersonWizardPayload, db: DbSession):
    try:
        new_person = await create_person_from_wizard(db, payload)
        return {"message": "Persona creata con successo", "tax_code": new_person.tax_code}
    except HTTPException as http_exc:
        await db.rollback()
        raise http_exc from None
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Errore didnt creato: {str(e)}"
        )


@router.post("/{tax_code}/image", status_code=status.HTTP_200_OK)
async def upload_profile_image(
    tax_code: str,
    db: DbSession,
    file: UploadFile = File(...),
):
    person = await db.get(Person, tax_code)
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    upload_dir = "uploads/profile-images"
    os.makedirs(upload_dir, exist_ok=True)
    
    safe_filename = file.filename or "profile.jpg"
    ext           = safe_filename.split(".")[-1] if "." in safe_filename else "jpg"
    
    file_name = f"{tax_code}.{ext}"
    file_path = os.path.join(upload_dir, file_name)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    image_url = f"/{upload_dir}/{file_name}"
    person.profile_image_url = image_url
    await db.commit()
    
    return {"profile_image_url": image_url}


@router.put("/{tax_code}/memberships", status_code=status.HTTP_200_OK)
async def update_person_memberships(tax_code: str, payload: PersonMembershipsUpdate, db: DbSession):
    if not payload.memberships:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossibile salvare lo storico iscrizioni vuoto. È necessaria almeno un'iscrizione."
        )

    stmt = (
        select(Person)
        .options(joinedload(Person.member_profile).joinedload(Member.memberships))
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    member = person.member_profile
    if not member:
        raise HTTPException(status_code=400, detail="L'utente non possiede un profil da associato.")
        
    years = [m_data.year for m_data in payload.memberships]
    if len(years) != len(set(years)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non è possibile registrare più di un'iscrizione per lo stesso anno."
        )

    member.collaborating_active = payload.collaborating_active
    
    for m in list(member.memberships):
        await db.delete(m)
        
    await db.flush() 
    member.memberships.clear()
    
    for m_data in payload.memberships:
        new_m = Membership(
            member_tax_code=person.tax_code,
            year=m_data.year,
            start_date=m_data.start_date,
            end_date=m_data.end_date,
            renewal_period_days=m_data.renewal_period_days,
            revocation=MembershipRevocationEnum(m_data.revocation)
        )
        db.add(new_m)
        
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Errore durante l'aggiornamento delle iscrizioni: {str(e)}"
        )
        
    return {"message": "Iscrizioni aggiornate con successo"}


@router.put("/{tax_code}/revoke-membership", status_code=status.HTTP_200_OK)
async def revoke_person_membership(tax_code: str, payload: RevokeMembershipPayload, db: DbSession):
    stmt = (
        select(Person)
        .options(joinedload(Person.member_profile).joinedload(Member.memberships))
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    member = person.member_profile
    if not member:
        raise HTTPException(status_code=400, detail="L'utente non possiede un profilo da associato.")
        
    if not member.memberships:
        raise HTTPException(status_code=400, detail="Nessuna iscrizione trouvata da revocare.")
        
    latest_membership = max(member.memberships, key=lambda m: m.year)
    
    if latest_membership.revocation != MembershipRevocationEnum.NO:
        raise HTTPException(status_code=400, detail="L'iscrizione per l'anno corrente risulta già revocata.")
        
    today = date.today()
    
    latest_membership.end_date            = today
    latest_membership.renewal_period_days = 0
    latest_membership.revocation          = MembershipRevocationEnum(payload.revocation_type)
    
    member.collaborating_active = False
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Errore durante la revoca dell'iscrizione: {str(e)}"
        )
        
    return {"message": "Iscrizione revocata con successo"}

@router.put("/{tax_code}/teacher-competences", status_code=status.HTTP_200_OK)
async def update_teacher_competences(tax_code: str, payload: PersonTeacherCompetencesUpdate, db: DbSession):
    if not payload.competences:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossibile svuotare le discipline. Un docente deve insegnare almeno una materia."
        )

    stmt = (
        select(Person)
        .options(joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.teacher_profile).joinedload(Teacher.teaching_competences))
        .where(Person.tax_code == tax_code.upper())
    )
    result = await db.execute(stmt)
    person = result.unique().scalar_one_or_none()
    
    if not person:
        raise HTTPException(status_code=404, detail="Persona non trovata")
        
    member = person.member_profile
    if not member or not member.staff_profile or not member.staff_profile.teacher_profile:
        raise HTTPException(status_code=400, detail="L'utente non possiede un profilo da docente.")
        
    teacher = member.staff_profile.teacher_profile
    
    for comp in list(teacher.teaching_competences):
        await db.delete(comp)
        
    await db.flush() 
    teacher.teaching_competences.clear()
    
    for comp_data in payload.competences:
        if not comp_data.study_program_ids:
            continue
        for sp_id in comp_data.study_program_ids:
            new_comp = TeachingCompetence(
                teacher_tax_code=person.tax_code,
                association_subject_id=comp_data.subject_id, 
                study_program_id=sp_id
            )
            db.add(new_comp)
            
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Errore durante l'aggiornamento delle competenze: {str(e)}"
        )
        
    return {"message": "Discipline aggiornate con successo"}