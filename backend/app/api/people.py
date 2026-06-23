import os
import shutil
from datetime import date, datetime

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.schemas.person_wizard import PersonWizardPayload
from app.services.person_wizard_service import create_person_from_wizard

from ..models.member import Member
from ..models.parent import Parent
from ..models.person import Person
from ..models.school_enrollment import SchoolEnrollment
from ..models.school_study_program import SchoolStudyProgram
from ..models.staff import Staff
from ..models.student import Student
from ..models.teacher import Teacher
from ..models.teaching_competence import TeachingCompetence
from ..schemas.person import PersonResponse
from .dependencies import DbSession

router = APIRouter(prefix="/people", tags=["people"])

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

@router.get("/", response_model=list[PersonResponse])
async def get_people(db: DbSession):
    stmt = (
        select(Person)
        .options(
            joinedload(Person.account),
            joinedload(Person.parent_profile).joinedload(Parent.children_relationships),
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
            joinedload(Person.member_profile).joinedload(Member.staff_profile).joinedload(Staff.psychologist_profile),
        )
    )
    
    result = await db.execute(stmt)
    people = result.unique().scalars().all()
    
    results = []
    today   = date.today()

    for p in people:
        roles                  = []
        is_active_collab       = None
        enrollment_year        = None
        collab_type_translated = None
        is_med_cert_valid      = None
        course_type            = None
        education_level        = None
        school_name            = None
        school_class           = None
        study_program          = None
        early_exit             = None
        taught_subjects_list   = []
        
        if p.parent_profile is not None:
            roles.append('Genitore')
            
        member = p.member_profile
        
        if member is not None:
            roles.append('Associato')
            is_active_collab = member.collaborating_active
            
            if member.memberships:
                first_membership = min(member.memberships, key=lambda m: m.year)
                enrollment_year  = str(first_membership.year)

            if member.course_participant_profile is not None:
                roles.append('Corsista')
                course_profile = member.course_participant_profile
                course_type    = course_profile.course_type
                
                if course_profile.medical_certificate_expiration:
                    is_med_cert_valid = course_profile.medical_certificate_expiration >= today
                else:
                    is_med_cert_valid = False

            if member.student_profile is not None:
                roles.append('Studente')
                student    = member.student_profile
                early_exit = student.authorized_early_exit
                
                if student.school_enrollments:
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
                
                if staff.administrator_profile is not None:
                    roles.append('Amministratore')
                    
                if staff.teacher_profile is not None:
                    roles.append('Docente')
                    subjects_set = set()
                    
                    for comp in staff.teacher_profile.teaching_competences:
                        if comp.association_subject:
                            subjects_set.add(comp.association_subject.name)
                            
                    taught_subjects_list = sorted(list(subjects_set))
                    
                if staff.psychologist_profile is not None:
                    roles.append('Psicologo')

        profile_img    = p.profile_image_url
        children_count = len(p.parent_profile.children_relationships) if p.parent_profile else None
        
        person_response = PersonResponse(
            fiscal_code=p.tax_code,
            first_name=p.first_name,
            last_name=p.last_name,
            roles=roles,
            created_at=getattr(p, 'created_at', datetime.now()),
            profile_image_url=profile_img, 
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
            taught_subjects=taught_subjects_list
        )
        results.append(person_response)
        
    return results

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
            detail=f"Errore critico durante il salvataggio dei dati: {str(e)}"
        ) from e


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
    
    # Sicurezza: usa un nome di default se il filename è None
    safe_filename = file.filename or "profile.jpg"
    ext = safe_filename.split(".")[-1] if "." in safe_filename else "jpg"
    
    file_name = f"{tax_code}.{ext}"
    file_path = os.path.join(upload_dir, file_name)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    image_url = f"/{upload_dir}/{file_name}"
    person.profile_image_url = image_url
    await db.commit()
    
    return {"profile_image_url": image_url}