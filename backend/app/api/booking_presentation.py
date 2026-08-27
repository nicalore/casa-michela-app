# Shared response shaping for /bookings, /presences and /lesson-requests.

from collections.abc import Iterable, Iterator, Sequence

from app.models.booking import Booking
from app.models.booking_teacher_preference import TeacherPreferenceTypeEnum
from app.models.person import Person
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.booking import BookingSummaryResponse
from app.schemas.person import PersonOption


# Teacher names live on Person; resolved via PersonRepository.get_options in
# one batched query per response.
def teacher_tax_codes(bookings: Iterable[Booking]) -> Iterator[str]:
    return (
        preference.teacher_tax_code
        for booking in bookings
        for preference in booking.teacher_preferences
    )


def _teachers_of(
    booking: Booking,
    people: dict[str, Person],
    preference_type: TeacherPreferenceTypeEnum,
) -> list[PersonOption]:
    return [
        PersonOption.model_validate(people[preference.teacher_tax_code])
        for preference in booking.teacher_preferences
        if preference.preference_type is preference_type
        and preference.teacher_tax_code in people
    ]


def booking_summary(
    booking: Booking,
    people: dict[str, Person],
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
        preferred_teachers=_teachers_of(
            booking,
            people,
            TeacherPreferenceTypeEnum.PREFERRED,
        ),
        not_preferred_teachers=_teachers_of(
            booking,
            people,
            TeacherPreferenceTypeEnum.NOT_PREFERRED,
        ),
        created_at=booking.created_at,
        updated_at=booking.updated_at,
    )


def booking_summaries(
    bookings: Sequence[Booking],
    people: dict[str, Person],
) -> list[BookingSummaryResponse]:
    return [booking_summary(booking, people) for booking in bookings]
