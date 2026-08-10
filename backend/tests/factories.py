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
from app.models.service import Service
from app.models.staff import Staff
from app.models.student import Student
from app.models.study_program import StudyProgram
from app.models.subject_requested import SubjectRequested
from app.models.teacher import Teacher
from app.models.teaching_competence import TeachingCompetence

# The chain from a person down to a teacher is four tables deep, and every one
# of them is needed before a single availability can exist. Without these,
# every test would open with twenty lines of setup that say nothing about what
# it is testing.

_counter = count(1)


# Built with the model's own tables rather than a hard-coded list of valid
# codes: Person validates the check character in Python, so a fixture that
# guessed would fail on the day somebody read the algorithm again.
def make_tax_code(seed: int) -> str:
    # Six letters, two digits of year, a month letter, two of day, then the
    # town code: fifteen characters, and the sixteenth is the check.
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
    seed = next(_counter)
    person = Person(
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
    )

    db.add(person)
    await db.flush()

    return person


async def make_teacher(
    db: AsyncSession,
    *,
    first_name: str = "Anna",
    last_name: str = "Bianchi",
) -> Teacher:
    person = await make_person(db, first_name=first_name, last_name=last_name)

    db.add(Member(tax_code=person.tax_code))
    await db.flush()

    db.add(Staff(tax_code=person.tax_code, collaboration_type="VOLUNTEER"))
    await db.flush()

    teacher = Teacher(tax_code=person.tax_code)
    db.add(teacher)
    await db.flush()

    return teacher


async def make_student(
    db: AsyncSession,
    *,
    first_name: str = "Luca",
    last_name: str = "Verdi",
) -> Student:
    person = await make_person(db, first_name=first_name, last_name=last_name)

    db.add(Member(tax_code=person.tax_code))
    await db.flush()

    student = Student(tax_code=person.tax_code)
    db.add(student)
    await db.flush()

    return student


async def make_discipline(
    db: AsyncSession,
    *,
    name: str | None = None,
) -> AssociationSubject:
    subject = AssociationSubject(
        name=name or f"Disciplina {next(_counter)}",
        area=SubjectAreaEnum.SCIENCES,
    )

    db.add(subject)
    await db.flush()

    return subject


async def make_study_program(db: AsyncSession) -> StudyProgram:
    program = StudyProgram(
        level="HIGH_SCHOOL",
        name=f"Indirizzo {next(_counter)}",
        min_year=1,
        max_year=5,
    )

    db.add(program)
    await db.flush()

    return program


# Competence is keyed by study programme as well, but a lesson has no way of
# knowing which one applies, so the service only ever asks about the pair. Any
# programme will do here.
async def make_competence(
    db: AsyncSession,
    teacher: Teacher,
    subject: AssociationSubject,
    study_program: StudyProgram | None = None,
) -> None:
    program = study_program or await make_study_program(db)

    db.add(
        TeachingCompetence(
            teacher_tax_code=teacher.tax_code,
            association_subject_id=subject.id,
            study_program_id=program.id,
        ),
    )
    await db.flush()


async def make_administrator(db: AsyncSession) -> Administrator:
    person = await make_person(db, first_name="Giulia", last_name="Neri")

    db.add(Member(tax_code=person.tax_code))
    await db.flush()

    db.add(Staff(tax_code=person.tax_code, collaboration_type="VOLUNTEER"))
    await db.flush()

    # OTHER, because the three named roles each have a partial unique index and
    # two tests wanting an administrator would collide on it. That role is the
    # one that has to say what it is.
    administrator = Administrator(
        tax_code=person.tax_code,
        role="OTHER",
        other_role="Segreteria",
    )
    db.add(administrator)
    await db.flush()

    return administrator


async def make_parent_of(db: AsyncSession, student: Student) -> Parent:
    person = await make_person(db, first_name="Paolo", last_name="Gialli")

    parent = Parent(tax_code=person.tax_code)
    db.add(parent)
    await db.flush()

    db.add(
        ParentalResponsibility(
            parent_tax_code=parent.tax_code,
            child_tax_code=student.tax_code,
        ),
    )
    await db.flush()

    return parent


async def make_service(db: AsyncSession) -> Service:
    service = Service(name=f"Servizio {next(_counter)}")

    db.add(service)
    await db.flush()

    return service


async def make_availability(
    db: AsyncSession,
    teacher: Teacher,
    *,
    day: date,
    start_time: time = time(14),
    end_time: time = time(19),
    mode: str = "presence",
) -> Availability:
    availability = Availability(
        teacher_tax_code=teacher.tax_code,
        date=day,
        mode=mode,
        start_time=start_time,
        end_time=end_time,
    )

    db.add(availability)
    await db.flush()

    return availability


async def make_presence(
    db: AsyncSession,
    student: Student,
    *,
    day: date,
    start_time: time = time(14),
    end_time: time = time(19),
    mode: str = "presence",
) -> Presence:
    presence = Presence(
        date=day,
        mode=mode,
        start_time=start_time,
        end_time=end_time,
        student_tax_code=student.tax_code,
        # No parents on a factory-built pupil, so the pupil is their own booker,
        # which is the case the Presence hook allows.
        booker_tax_code=student.tax_code,
    )

    db.add(presence)
    await db.flush()

    return presence


# Defaults to the simplest of the three shapes a request can take, a single
# discipline: a booking with none of them at all is refused by the model, and a
# ministry request would need its subjects wired up for no gain here.
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

    booking = Booking(
        presence_id=presence.id,
        duration=duration,
        association_subject_id=association_subject_id,
        service_name=service_name,
    )

    db.add(booking)
    await db.flush()

    return booking


# The third shape a request can take: a ministry subject with the disciplines
# asked for under it. The only one that can carry more than one discipline, so
# the only one that shows a covering apart from a single subject.
async def make_ministry_request(
    db: AsyncSession,
    presence: Presence,
    subjects: list[AssociationSubject],
    *,
    duration: int = 120,
) -> tuple[Booking, MinistrySubject]:
    ministry = MinistrySubject(
        level="HIGH_SCHOOL",
        name=f"Materia {next(_counter)}",
        area=[SubjectAreaEnum.SCIENCES],
    )

    db.add(ministry)
    await db.flush()

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

    db.add(booking)
    await db.flush()

    return booking, ministry


async def make_room(
    db: AsyncSession,
    *,
    name: str | None = None,
    capacity: int | None = None,
) -> Room:
    room = Room(name=name or f"Aula {next(_counter)}", capacity=capacity)

    db.add(room)
    await db.flush()

    return room
