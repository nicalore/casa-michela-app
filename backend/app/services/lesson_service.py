from collections.abc import Sequence
from datetime import date, time
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select

from app.api.rbac import IdentityContext
from app.core.integrity import integrity_guard
from app.core.optimistic_concurrency import assert_not_stale
from app.core.time_band import assert_within_single_band
from app.models.association_subject import AssociationSubject
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.booking_teacher_preference import (
    BookingTeacherPreference,
    TeacherPreferenceTypeEnum,
)
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence
from app.repositories.booking_repository import BOOKING_EAGER_LOADER
from app.repositories.lesson_repository import LessonRepository, LessonVisibility
from app.repositories.person_repository import PersonRepository
from app.schemas.lesson import LessonCreate, LessonUpdate
from app.services.lesson_guard import (
    assert_band_not_published,
    assert_bands_not_published,
)

_ENTITY_LABEL: Final[str] = "la lezione"
_NOT_FOUND_ERROR: Final[str] = "Lezione non trovata"
_CREATE_ERROR: Final[str] = "Errore durante la creazione della lezione."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_AVAILABILITY_NOT_FOUND_ERROR: Final[str] = "Disponibilità non trovata"

_UNKNOWN_BOOKINGS_ERROR: Final[str] = (
    "Alcune prenotazioni non esistono: {ids}."
)

_UNKNOWN_DISCIPLINES_ERROR: Final[str] = (
    "Alcune discipline non esistono: {ids}."
)

_OUTSIDE_AVAILABILITY_ERROR: Final[str] = (
    "La lezione deve stare dentro la disponibilità del docente "
    "({start} - {end})."
)

_MIXED_MODES_ERROR: Final[str] = (
    "Le prenotazioni di una lezione devono essere tutte nella stessa modalità."
)

_TEACHER_AT_HOME_ERROR: Final[str] = (
    "Un docente collegato da casa non può tenere una lezione in presenza."
)

_WRONG_DAY_ERROR: Final[str] = (
    "La prenotazione di {student} non è nel giorno della disponibilità."
)

_OUTSIDE_PRESENCE_ERROR: Final[str] = (
    "La lezione non rientra nelle ore di {student} ({start} - {end})."
)

_TEACHER_OVERLAP_ERROR: Final[str] = (
    "Il docente ha già una lezione che si sovrappone a questo orario."
)

_STUDENT_OVERLAP_ERROR: Final[str] = (
    "Uno studente della lezione è già impegnato in un'altra lezione a "
    "quest'ora."
)

_MISSING_COMPETENCE_ERROR: Final[str] = (
    "Il docente non ha la competenza per: {subjects}."
)

_MISSING_SERVICE_ERROR: Final[str] = (
    "Il docente non eroga il servizio: {services}."
)

_NOT_PREFERRED_WARNING: Final[str] = (
    "Il docente {teacher} è indicato come non preferito da {student}."
)


def _format_time(value: time) -> str:
    return value.strftime("%H:%M")


def _person_label(person: object) -> str:
    first = getattr(person, "first_name", "") or ""
    last = getattr(person, "last_name", "") or ""

    return f"{first} {last}".strip()


class LessonService:
    def __init__(self, repository: LessonRepository) -> None:
        self.repository = repository

    @property
    def session(self):  # noqa: ANN201 - mirrors the other services
        return self.repository.session

    # Read as a union of the roles held and not as a switch on one of them: an
    # account can be a parent and a teacher at once, and a pupil is not the
    # booker whenever a parent booked for them.
    def _visibility_for(self, identity: IdentityContext) -> LessonVisibility:
        if identity.is_admin:
            return LessonVisibility()

        student_tax_codes = set()

        if "STUDENT" in identity.roles:
            student_tax_codes.add(identity.tax_code)

        if "PARENT" in identity.roles:
            student_tax_codes |= set(identity.child_tax_codes)

        return LessonVisibility(
            teacher_tax_code=(
                identity.tax_code if "TEACHER" in identity.roles else None
            ),
            student_tax_codes=frozenset(student_tax_codes),
            booker_tax_code=identity.tax_code,
            published_only=True,
        )

    async def _availability_or_404(self, availability_id: int) -> Availability:
        availability = await self.session.scalar(
            select(Availability).where(Availability.id == availability_id),
        )

        if availability is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_AVAILABILITY_NOT_FOUND_ERROR,
            )

        return availability

    async def _bookings_or_400(self, booking_ids: Sequence[int]) -> list[Booking]:
        rows = (
            (
                await self.session.execute(
                    select(Booking)
                    .options(*BOOKING_EAGER_LOADER)
                    .where(Booking.id.in_(booking_ids)),
                )
            )
            .scalars()
            .all()
        )

        found = {booking.id: booking for booking in rows}
        missing = [
            booking_id for booking_id in booking_ids if booking_id not in found
        ]

        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_UNKNOWN_BOOKINGS_ERROR.format(
                    ids=", ".join(str(value) for value in missing),
                ),
            )

        return [found[booking_id] for booking_id in booking_ids]

    def _assert_within_availability(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
    ) -> None:
        if (
            start_time < availability.start_time
            or end_time > availability.end_time
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OUTSIDE_AVAILABILITY_ERROR.format(
                    start=_format_time(availability.start_time),
                    end=_format_time(availability.end_time),
                ),
            )

    # The lesson's own mode is the pupils': they are all in it the same way. A
    # teacher in the building can serve either, a teacher at home only the
    # screen.
    async def _resolve_mode(
        self,
        availability: Availability,
        bookings: Sequence[Booking],
        start_time: time,
        end_time: time,
    ) -> tuple[str, set[str]]:
        modes = {booking.presence.mode for booking in bookings}

        if len(modes) > 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_MIXED_MODES_ERROR,
            )

        mode = modes.pop()

        if availability.mode == "online" and mode == "presence":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_TEACHER_AT_HOME_ERROR,
            )

        students = set()
        people = await PersonRepository(self.session).get_options(
            booking.presence.student_tax_code for booking in bookings
        )

        for booking in bookings:
            presence = booking.presence
            student = _person_label(people.get(presence.student_tax_code))

            if presence.date != availability.date:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_WRONG_DAY_ERROR.format(student=student),
                )

            if (
                start_time < presence.start_time
                or end_time > presence.end_time
            ):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_OUTSIDE_PRESENCE_ERROR.format(
                        student=student,
                        start=_format_time(presence.start_time),
                        end=_format_time(presence.end_time),
                    ),
                )

            students.add(presence.student_tax_code)

        return mode, students

    async def _assert_no_overlaps(
        self,
        *,
        availability: Availability,
        student_tax_codes: set[str],
        start_time: time,
        end_time: time,
        exclude_id: int | None,
    ) -> None:
        # No filter on mode, and that is where this rule parts company with
        # AvailabilityService._assert_no_overlap: availabilities may overlap
        # between the two modes, lessons may not, because nobody teaches two
        # groups at once.
        clash = await self.repository.find_teacher_overlap(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
            exclude_id=exclude_id,
        )

        if clash is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_TEACHER_OVERLAP_ERROR,
            )

        busy = await self.repository.find_student_overlap(
            student_tax_codes=student_tax_codes,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
            exclude_id=exclude_id,
        )

        if busy is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_STUDENT_OVERLAP_ERROR,
            )

    async def _disciplines_or_400(
        self,
        association_subject_ids: Sequence[int],
    ) -> list[AssociationSubject]:
        if not association_subject_ids:
            return []

        rows = (
            (
                await self.session.execute(
                    select(AssociationSubject).where(
                        AssociationSubject.id.in_(association_subject_ids),
                    ),
                )
            )
            .scalars()
            .all()
        )

        found = {subject.id: subject for subject in rows}
        missing = [
            subject_id
            for subject_id in association_subject_ids
            if subject_id not in found
        ]

        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_UNKNOWN_DISCIPLINES_ERROR.format(
                    ids=", ".join(str(value) for value in missing),
                ),
            )

        return [found[subject_id] for subject_id in association_subject_ids]

    # Not a preference but a capability, so a hard refusal. Checked on the pair
    # (teacher, discipline) alone: teaching_competences is also keyed by study
    # programme, and a lesson has no way of knowing which one applies without
    # reading enrolments that may not exist.
    async def _assert_competences(
        self,
        teacher_tax_code: str,
        disciplines: Sequence[AssociationSubject],
        bookings: Sequence[Booking],
    ) -> None:
        if disciplines:
            competent = set(
                await self.session.scalars(
                    select(TeachingCompetence.association_subject_id).where(
                        TeachingCompetence.teacher_tax_code == teacher_tax_code,
                        TeachingCompetence.association_subject_id.in_(
                            [subject.id for subject in disciplines],
                        ),
                    ),
                ),
            )

            lacking = [
                subject.name
                for subject in disciplines
                if subject.id not in competent
            ]

            if lacking:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=_MISSING_COMPETENCE_ERROR.format(
                        subjects=", ".join(sorted(lacking)),
                    ),
                )

            return

        service_names = {
            booking.service_name
            for booking in bookings
            if booking.service_name is not None
        }

        if not service_names:
            return

        offered = set(
            await self.session.scalars(
                select(TeacherService.service_name).where(
                    TeacherService.teacher_tax_code == teacher_tax_code,
                    TeacherService.service_name.in_(service_names),
                ),
            ),
        )

        lacking_services = sorted(service_names - offered)

        if lacking_services:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_MISSING_SERVICE_ERROR.format(
                    services=", ".join(lacking_services),
                ),
            )

    # NOT_PREFERRED says who the hour should go to last, not who is forbidden
    # it — see the comment on the model. Refusing outright would make the day
    # impossible to plan whenever the only competent teacher is the unwanted
    # one, which is exactly when the office has to be able to decide.
    async def _not_preferred_warnings(
        self,
        teacher_tax_code: str,
        bookings: Sequence[Booking],
    ) -> list[str]:
        booking_ids = [booking.id for booking in bookings]

        if not booking_ids:
            return []

        flagged = set(
            await self.session.scalars(
                select(BookingTeacherPreference.booking_id).where(
                    BookingTeacherPreference.booking_id.in_(booking_ids),
                    BookingTeacherPreference.teacher_tax_code == teacher_tax_code,
                    BookingTeacherPreference.preference_type
                    == TeacherPreferenceTypeEnum.NOT_PREFERRED,
                ),
            ),
        )

        if not flagged:
            return []

        people = await PersonRepository(self.session).get_options(
            [
                *(
                    booking.presence.student_tax_code
                    for booking in bookings
                    if booking.id in flagged
                ),
                teacher_tax_code,
            ],
        )
        teacher = _person_label(people.get(teacher_tax_code))

        return [
            _NOT_PREFERRED_WARNING.format(
                teacher=teacher,
                student=_person_label(
                    people.get(booking.presence.student_tax_code),
                ),
            )
            for booking in bookings
            if booking.id in flagged
        ]

    async def _validate(
        self,
        payload: LessonCreate | LessonUpdate,
        *,
        exclude_id: int | None,
    ) -> tuple[Availability, str, list[Booking], list[AssociationSubject], list[str]]:
        availability = await self._availability_or_404(payload.availability_id)

        # A lesson lives in one band, and a published band is settled.
        band = assert_within_single_band(payload.start_time, payload.end_time)
        await assert_band_not_published(self.session, availability.date, band)

        self._assert_within_availability(
            availability,
            payload.start_time,
            payload.end_time,
        )

        bookings = await self._bookings_or_400(payload.booking_ids)
        mode, student_tax_codes = await self._resolve_mode(
            availability,
            bookings,
            payload.start_time,
            payload.end_time,
        )

        await self._assert_no_overlaps(
            availability=availability,
            student_tax_codes=student_tax_codes,
            start_time=payload.start_time,
            end_time=payload.end_time,
            exclude_id=exclude_id,
        )

        disciplines = await self._disciplines_or_400(
            payload.association_subject_ids,
        )
        await self._assert_competences(
            availability.teacher_tax_code,
            disciplines,
            bookings,
        )

        warnings = await self._not_preferred_warnings(
            availability.teacher_tax_code,
            bookings,
        )

        return availability, mode, bookings, disciplines, warnings

    async def list_for(
        self,
        identity: IdentityContext,
        *,
        date_from: date | None,
        date_to: date | None,
        band: str | None,
        mode: str | None,
        teacher_tax_code: str | None,
    ) -> Sequence[Lesson]:
        return await self.repository.list(
            visibility=self._visibility_for(identity),
            date_from=date_from,
            date_to=date_to,
            band=band,
            mode=mode,
            teacher_tax_code=teacher_tax_code,
        )

    async def get_visible_or_404(
        self,
        identity: IdentityContext,
        lesson_id: int,
    ) -> Lesson:
        lesson = await self.repository.get_by_id(
            lesson_id,
            visibility=self._visibility_for(identity),
        )

        if lesson is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return lesson

    async def create(self, payload: LessonCreate) -> tuple[Lesson, list[str]]:
        availability, mode, bookings, disciplines, warnings = await self._validate(
            payload,
            exclude_id=None,
        )

        # The availability is assigned as an object and never as an id: it is the
        # relationship that fills in date and teacher_mode, which are two thirds
        # of the composite key.
        #
        # Built and flushed in one go, because the hooks have to see the lesson,
        # its links and its disciplines together: flushing the lesson alone would
        # trip the rule that a lesson has at least one booking.
        lesson = Lesson(
            availability=availability,
            mode=mode,
            start_time=payload.start_time,
            end_time=payload.end_time,
            lesson_bookings=[
                LessonBooking(booking=booking) for booking in bookings
            ],
            lesson_disciplines=[
                LessonDiscipline(association_subject_id=subject.id)
                for subject in disciplines
            ],
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(lesson)
            await self.repository.commit()

        return await self._reload(lesson.id), warnings

    async def update(
        self,
        identity: IdentityContext,
        lesson_id: int,
        payload: LessonUpdate,
    ) -> tuple[Lesson, list[str]]:
        lesson = await self.get_visible_or_404(identity, lesson_id)

        assert_not_stale(
            lesson,
            payload.expected_updated_at,
            entity_label=_ENTITY_LABEL,
        )

        # Both ends of the move: where the lesson is now and where it is going.
        await assert_bands_not_published(
            self.session,
            [(lesson.date, lesson.band)],
        )

        availability, mode, bookings, disciplines, warnings = await self._validate(
            payload,
            exclude_id=lesson.id,
        )

        lesson.availability = availability
        lesson.mode = mode
        lesson.start_time = payload.start_time
        lesson.end_time = payload.end_time
        lesson.lesson_bookings = [
            LessonBooking(booking=booking) for booking in bookings
        ]
        lesson.lesson_disciplines = [
            LessonDiscipline(association_subject_id=subject.id)
            for subject in disciplines
        ]

        async with integrity_guard(self.session, _UPDATE_ERROR):
            await self.repository.commit()

        return await self._reload(lesson.id), warnings

    async def delete(self, identity: IdentityContext, lesson_id: int) -> None:
        lesson = await self.get_visible_or_404(identity, lesson_id)

        await assert_band_not_published(self.session, lesson.date, lesson.band)

        await self.repository.delete(lesson)
        await self.repository.commit()

    # Read back after writing: band is computed by the database and updated_at is
    # set by it, and reaching for either once the request has left the session
    # would be IO where none can be done.
    async def _reload(self, lesson_id: int) -> Lesson:
        lesson = await self.repository.get_by_id(
            lesson_id,
            visibility=LessonVisibility(),
        )

        if lesson is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=_NOT_FOUND_ERROR,
            )

        return lesson
