# Shared response shaping for /bookings, /presences and /lesson-requests.

from collections.abc import Iterable, Iterator, Sequence
from itertools import chain

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking
from app.models.person import Person
from app.models.student_not_preferred_teacher import StudentNotPreferredTeacher
from app.repositories.person_repository import PersonRepository
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.booking import BookingSummaryResponse
from app.schemas.person import PersonOption

# Student tax code → teachers the pupil would rather not have, as of today.
AvoidedTeachers = dict[str, list[str]]


def teacher_tax_codes(bookings: Iterable[Booking]) -> Iterator[str]:
    return (
        preference.teacher_tax_code
        for booking in bookings
        for preference in booking.preferred_teachers
    )


async def avoided_teachers(
    db: AsyncSession,
    student_tax_codes: Iterable[str],
) -> AvoidedTeachers:
    students = set(student_tax_codes)

    if not students:
        return {}

    rows = await db.execute(
        select(
            StudentNotPreferredTeacher.student_tax_code,
            StudentNotPreferredTeacher.teacher_tax_code,
        )
        .where(
            StudentNotPreferredTeacher.student_tax_code.in_(students),
            StudentNotPreferredTeacher.valid_to.is_(None),
        )
        .order_by(StudentNotPreferredTeacher.teacher_tax_code),
    )
    avoided: AvoidedTeachers = {}

    for student_tax_code, teacher_tax_code in rows.all():
        avoided.setdefault(student_tax_code, []).append(teacher_tax_code)

    return avoided


# Everyone a booking response names, in two batched queries: the pupils'
# standing lists first, so those teachers get their names too.
async def booking_people(
    db: AsyncSession,
    bookings: Sequence[Booking],
    *,
    students: Iterable[str],
    also: Iterable[str] = (),
) -> tuple[dict[str, Person], AvoidedTeachers]:
    students = set(students)
    avoided = await avoided_teachers(db, students)
    people = await PersonRepository(db).get_options(
        chain(
            students,
            also,
            teacher_tax_codes(bookings),
            chain.from_iterable(avoided.values()),
        ),
    )

    return people, avoided


def person_options(
    tax_codes: Iterable[str],
    people: dict[str, Person],
) -> list[PersonOption]:
    return [
        PersonOption.model_validate(people[tax_code])
        for tax_code in tax_codes
        if tax_code in people
    ]


def booking_summary(
    booking: Booking,
    people: dict[str, Person],
    avoided_tax_codes: Sequence[str],
) -> BookingSummaryResponse:
    association_subjects = [
        AssociationSubjectOption.model_validate(
            subject_requested.ministry_association_subject.association_subject
        )
        for subject_requested in booking.subjects_requested
    ]

    # Request kinds are told apart by what is filled in.
    ministry_subject_id = (
        booking.subjects_requested[0].ministry_subject_id
        if booking.subjects_requested
        else None
    )

    return BookingSummaryResponse(
        id=booking.id,
        duration=booking.duration,
        ministry_subject_id=ministry_subject_id,
        association_subjects=association_subjects,
        association_subject=(
            AssociationSubjectOption.model_validate(booking.association_subject)
            if booking.association_subject is not None
            else None
        ),
        service_name=booking.service_name,
        tags=booking.tags,
        topic=booking.topic,
        notes=booking.notes,
        preferred_teachers=person_options(teacher_tax_codes([booking]), people),
        not_preferred_teachers=person_options(avoided_tax_codes, people),
        created_at=booking.created_at,
        updated_at=booking.updated_at,
    )


# One pupil's bookings: they all share the pupil's list.
def booking_summaries(
    bookings: Sequence[Booking],
    people: dict[str, Person],
    avoided_tax_codes: Sequence[str],
) -> list[BookingSummaryResponse]:
    return [
        booking_summary(booking, people, avoided_tax_codes) for booking in bookings
    ]
