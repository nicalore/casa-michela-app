from datetime import date, time
from itertools import count
from string import ascii_uppercase

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator import Administrator
from app.models.association_subject import AssociationSubject, SubjectAreaEnum
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.member import Member
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.ministry_subject import MinistrySubject
from app.models.parent import Parent
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import (
    _TAX_CODE_CHECK_CHARACTERS,
    _TAX_CODE_EVEN_POSITION_VALUES,
    _TAX_CODE_ODD_POSITION_VALUES,
    Person,
)
from app.models.presence import Presence
from app.models.room import Room
from app.models.school import School
from app.models.school_enrollment import SchoolEnrollment
from app.models.school_study_program import SchoolStudyProgram
from app.models.service import Service
from app.models.staff import Staff
from app.models.student import Student
from app.models.study_program import HighSchoolTrackEnum, StudyProgram
from app.models.study_program_subject import StudyProgramSubject
from app.models.subject_requested import SubjectRequested
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence
from tests.conftest import ADMIN_TAX_CODE

_counter = count(1)


# Skip any seed producing ADMIN_TAX_CODE (reached at seed 999): that code is
# already seeded by conftest, and reusing it would fail an unrelated test.
def _next_seed() -> int:
    seed = next(_counter)

    while make_tax_code(seed) == ADMIN_TAX_CODE:
        seed = next(_counter)

    return seed


async def _persist[T](db: AsyncSession, entity: T) -> T:
    db.add(entity)
    await db.flush()

    return entity


# Computes a real check character, since Person validates it.
def make_tax_code(seed: int) -> str:
    initial = ascii_uppercase[(seed // 1000) % len(ascii_uppercase)]
    stem = f"{initial}AAAAA00A01A{seed % 1000:03d}"
    total = sum(
        (
            _TAX_CODE_ODD_POSITION_VALUES[character]
            if index % 2 == 0
            else _TAX_CODE_EVEN_POSITION_VALUES[character]
        )
        for index, character in enumerate(stem)
    )

    return stem + _TAX_CODE_CHECK_CHARACTERS[total % len(_TAX_CODE_CHECK_CHARACTERS)]


async def make_person(
    db: AsyncSession,
    *,
    first_name: str = "Mario",
    last_name: str = "Rossi",
) -> Person:
    seed = _next_seed()

    return await _persist(
        db,
        Person(
            tax_code=make_tax_code(seed),
            first_name=first_name,
            last_name=last_name,
            gender="M",
            birth_date=date(2000, 1, 1),
            birth_city="Verona",
            birth_nation="Italia",
            birth_province="VR",
            email=f"persona{seed}@example.com",
            phone="+390000000000",
            residence_type="Via",
            residence_address="Roma",
            residence_street_number="1",
            residence_city="Verona",
            residence_province="VR",
            postal_code="37100",
        ),
    )


async def _make_staff_person(
    db: AsyncSession,
    *,
    first_name: str,
    last_name: str,
) -> Person:
    person = await make_person(db, first_name=first_name, last_name=last_name)

    await _persist(db, Member(tax_code=person.tax_code))
    await _persist(
        db,
        Staff(tax_code=person.tax_code, collaboration_type="VOLUNTEER"),
    )

    return person


async def make_teacher(
    db: AsyncSession,
    *,
    first_name: str = "Anna",
    last_name: str = "Bianchi",
) -> Teacher:
    person = await _make_staff_person(db, first_name=first_name, last_name=last_name)

    return await _persist(db, Teacher(tax_code=person.tax_code))


async def make_student(
    db: AsyncSession,
    *,
    first_name: str = "Luca",
    last_name: str = "Verdi",
) -> Student:
    person = await make_person(db, first_name=first_name, last_name=last_name)

    await _persist(db, Member(tax_code=person.tax_code))

    return await _persist(db, Student(tax_code=person.tax_code))


async def make_administrator(db: AsyncSession) -> Administrator:
    person = await _make_staff_person(db, first_name="Giulia", last_name="Neri")

    # OTHER: the named roles have a partial unique index and would collide.
    return await _persist(
        db,
        Administrator(
            tax_code=person.tax_code,
            role="OTHER",
            other_role="Segreteria",
        ),
    )


async def make_parent_of(db: AsyncSession, student: Student) -> Parent:
    person = await make_person(db, first_name="Paolo", last_name="Gialli")
    parent = await _persist(db, Parent(tax_code=person.tax_code))

    await _persist(
        db,
        ParentalResponsibility(
            parent_tax_code=parent.tax_code,
            child_tax_code=student.tax_code,
        ),
    )

    return parent


async def make_discipline(
    db: AsyncSession,
    *,
    name: str | None = None,
) -> AssociationSubject:
    return await _persist(
        db,
        AssociationSubject(
            name=name or f"Disciplina {next(_counter)}",
            area=SubjectAreaEnum.SCIENCES,
        ),
    )


async def make_study_program(db: AsyncSession) -> StudyProgram:
    return await _persist(
        db,
        StudyProgram(
            level="HIGH_SCHOOL",
            name=f"Indirizzo {next(_counter)}",
            # The widest cycle that still holds make_enrollment's default grade.
            high_school_track=HighSchoolTrackEnum.QUADRIENNALE,
            min_year=1,
            max_year=4,
        ),
    )


async def _make_ministry_subject(db: AsyncSession) -> MinistrySubject:
    return await _persist(
        db,
        MinistrySubject(
            level="HIGH_SCHOOL",
            name=f"Materia {next(_counter)}",
            area=[SubjectAreaEnum.SCIENCES],
        ),
    )


# With no study_program a fresh one is made: competent, never mind which.
async def make_competence(
    db: AsyncSession,
    teacher: Teacher,
    subject: AssociationSubject,
    study_program: StudyProgram | None = None,
) -> None:
    program = study_program or await make_study_program(db)

    await _persist(
        db,
        TeachingCompetence(
            teacher_tax_code=teacher.tax_code,
            association_subject_id=subject.id,
            study_program_id=program.id,
        ),
    )


# The school exists only to satisfy the composite foreign key.
async def make_enrollment(
    db: AsyncSession,
    student: Student,
    study_program: StudyProgram,
    *,
    start_year: int = 2026,
    grade: int = 3,
) -> SchoolEnrollment:
    school = await _persist(
        db,
        School(name=f"Istituto {next(_counter)}", city="Torino", province="TO"),
    )

    await _persist(
        db,
        SchoolStudyProgram(
            study_program_id=study_program.id,
            school_id=school.id,
        ),
    )

    return await _persist(
        db,
        SchoolEnrollment(
            student_tax_code=student.tax_code,
            study_program_id=study_program.id,
            school_id=school.id,
            start_year=start_year,
            grade=grade,
        ),
    )


async def make_service(db: AsyncSession) -> Service:
    return await _persist(db, Service(name=f"Servizio {next(_counter)}"))


async def make_room(
    db: AsyncSession,
    *,
    name: str | None = None,
    capacity: int | None = None,
) -> Room:
    return await _persist(
        db,
        Room(name=name or f"Aula {next(_counter)}", capacity=capacity),
    )


async def make_availability(
    db: AsyncSession,
    teacher: Teacher,
    *,
    day: date,
    start_time: time = time(14),
    end_time: time = time(19),
    mode: str = "presence",
) -> Availability:
    return await _persist(
        db,
        Availability(
            teacher_tax_code=teacher.tax_code,
            date=day,
            mode=mode,
            start_time=start_time,
            end_time=end_time,
        ),
    )


async def make_presence(
    db: AsyncSession,
    student: Student,
    *,
    day: date,
    start_time: time = time(14),
    end_time: time = time(19),
    mode: str = "presence",
) -> Presence:
    return await _persist(
        db,
        Presence(
            date=day,
            mode=mode,
            start_time=start_time,
            end_time=end_time,
            student_tax_code=student.tax_code,
            booker_tax_code=student.tax_code,
        ),
    )


# The model refuses a booking with neither discipline nor service.
async def make_booking(
    db: AsyncSession,
    presence: Presence,
    *,
    duration: int = 60,
    association_subject_id: int | None = None,
    service_name: str | None = None,
) -> Booking:
    if association_subject_id is None and service_name is None:
        association_subject_id = (await make_discipline(db)).id

    return await _persist(
        db,
        Booking(
            presence_id=presence.id,
            duration=duration,
            association_subject_id=association_subject_id,
            service_name=service_name,
        ),
    )


# Only a discipline inside a programme is judged on the (discipline, programme)
# pair; one no programme covers is judged on the discipline alone.
async def make_discipline_in_programme(
    db: AsyncSession,
    subject: AssociationSubject,
    study_program: StudyProgram,
) -> MinistrySubject:
    ministry = await _make_ministry_subject(db)

    db.add(
        MinistryAssociationSubject(
            ministry_subject_id=ministry.id,
            association_subject_id=subject.id,
        ),
    )
    db.add(
        StudyProgramSubject(
            study_program_id=study_program.id,
            ministry_subject_id=ministry.id,
        ),
    )
    await db.flush()

    return ministry


# The only booking shape that carries more than one discipline.
async def make_ministry_request(
    db: AsyncSession,
    presence: Presence,
    subjects: list[AssociationSubject],
    *,
    duration: int = 120,
) -> tuple[Booking, MinistrySubject]:
    ministry = await _make_ministry_subject(db)

    for subject in subjects:
        db.add(
            MinistryAssociationSubject(
                ministry_subject_id=ministry.id,
                association_subject_id=subject.id,
            ),
        )

    await db.flush()

    booking = Booking(presence_id=presence.id, duration=duration)
    booking.subjects_requested = [
        SubjectRequested(
            ministry_subject_id=ministry.id,
            association_subject_id=subject.id,
        )
        for subject in subjects
    ]

    return await _persist(db, booking), ministry
