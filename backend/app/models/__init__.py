from app.models.account import Account
from app.models.administrator import Administrator
from app.models.course_participant import Courseparticipant
from app.models.member import Member
from app.models.membership import Membership
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.psychologist import Psychologist
from app.models.refresh_token import RefreshToken
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.staff import Staff
from app.models.student import Student
from app.models.study_program import StudyProgram
from app.models.subject import Subject
from app.models.teacher import Teacher
from app.models.teacher_subject import TeacherSubject
from app.models.teaching_competence import TeachingCompetence
from app.models.teaching_offering import TeachingOffering
from app.models.teaching_offering_subject import (
    TeachingOfferingSubject,
)
from app.models.teaching_offering_year import TeachingOfferingYear

__all__ = [
    "Account",
    "Administrator",
    "Member",
    "Membership",
    "Parent",
    "ParentalResponsibility",
    "Person",
    "Psychologist",
    "School",
    "SchoolEnrollment",
    "Staff",
    "Student",
    "StudyProgram",
    "Subject",
    "Teacher",
    "TeacherSubject",
    "TeachingCompetence",
    "TeachingOffering",
    "TeachingOfferingSubject",
    "TeachingOfferingYear",
    "Courseparticipant",
    "RefreshToken",
]
