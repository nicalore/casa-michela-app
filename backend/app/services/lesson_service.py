from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, time
from typing import Final, Protocol

from fastapi import HTTPException, status
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped

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
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.school_enrollment import SchoolEnrollment
from app.models.study_program_subject import StudyProgramSubject
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence
from app.repositories.booking_repository import BOOKING_EAGER_LOADER
from app.repositories.lesson_repository import LessonRepository, LessonVisibility
from app.repositories.person_repository import PersonRepository
from app.schemas.lesson import LessonCreate, LessonUpdate
from app.services.lesson_guard import (
    assert_band_claimed,
    assert_band_editable,
    assert_bands_claimed,
    assert_bands_editable,
)
from app.services.teacher_occupancy import (
    MAX_CONCURRENT_STUDENTS,
    online_cannot_overlap_error,
    overlaps_an_online_hour,
    peak_concurrent_students,
    spans_with,
    too_many_students_error,
)

_ENTITY_LABEL: Final[str] = "la lezione"
_NOT_FOUND_ERROR: Final[str] = "Lezione non trovata"
_CREATE_ERROR: Final[str] = "Errore durante la creazione della lezione."
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."

_AVAILABILITY_NOT_FOUND_ERROR: Final[str] = "Disponibilità non trovata"

_UNKNOWN_BOOKINGS_ERROR: Final[str] = "Alcune prenotazioni non esistono: {ids}."

_UNKNOWN_DISCIPLINES_ERROR: Final[str] = "Alcune discipline non esistono: {ids}."

_OUTSIDE_AVAILABILITY_ERROR: Final[str] = (
    "Fuori dalla disponibilità del docente ({start} - {end})."
)

_MIXED_MODES_ERROR: Final[str] = (
    "Una lezione si deve svolgere interamente nella stessa modalità."
)

_TEACHER_AT_HOME_ERROR: Final[str] = (
    "Un docente collegato da casa non può tenere una lezione in presenza."
)

_WRONG_DAY_ERROR: Final[str] = (
    "La prenotazione di {student} non è nel giorno della disponibilità."
)

_OUTSIDE_PRESENCE_ERROR: Final[str] = (
    "La lezione non rientra nelle ore di presenza di {student} ({start} - {end})."
)

_STUDENT_OVERLAP_ERROR: Final[str] = (
    "Uno studente ha già un'altra lezione a quest'ora."
)

_MISSING_COMPETENCE_ERROR: Final[str] = (
    "Il docente non ha la competenza per: {subjects}."
)

_MISSING_SERVICE_ERROR: Final[str] = "Il docente non ha la competenza per: {services}."

_NOT_PREFERRED_WARNING: Final[str] = (
    "Il docente {teacher} è indicato come non preferito da {student}."
)


class _HasId(Protocol):
    id: Mapped[int]


def _format_time(value: time) -> str:
    return value.strftime("%H:%M")


def _person_label(person: object) -> str:
    first = getattr(person, "first_name", "") or ""
    last = getattr(person, "last_name", "") or ""

    return f"{first} {last}".strip()


def _lacks_competence(
    subject: AssociationSubject,
    *,
    programmes: set[int],
    within: set[int],
    granted: set[tuple[int, int]],
    any_programme: set[int],
) -> bool:
    if not programmes or subject.id not in within:
        return subject.id not in any_programme

    return any((subject.id, programme) not in granted for programme in programmes)


@dataclass(frozen=True)
class _ValidatedLesson:
    availability: Availability
    mode: str
    bookings: list[Booking]
    disciplines: list[AssociationSubject]
    warnings: list[str]

    def links(self) -> list[LessonBooking]:
        return [LessonBooking(booking=booking) for booking in self.bookings]

    def discipline_rows(self) -> list[LessonDiscipline]:
        return [
            LessonDiscipline(association_subject_id=subject.id)
            for subject in self.disciplines
        ]


class LessonService:
    def __init__(self, repository: LessonRepository) -> None:
        self.repository = repository

    @property
    def session(self) -> AsyncSession:
        return self.repository.session

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

    async def _fetch_in_order_or_400[T: _HasId](
        self,
        stmt: Select[tuple[T]],
        identifiers: Sequence[int],
        *,
        error: str,
    ) -> list[T]:
        found = {row.id: row for row in (await self.session.scalars(stmt)).all()}
        missing = [value for value in identifiers if value not in found]

        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error.format(ids=", ".join(str(value) for value in missing)),
            )

        return [found[value] for value in identifiers]

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
        return await self._fetch_in_order_or_400(
            select(Booking)
            .options(*BOOKING_EAGER_LOADER)
            .where(Booking.id.in_(booking_ids)),
            booking_ids,
            error=_UNKNOWN_BOOKINGS_ERROR,
        )

    async def _disciplines_or_400(
        self,
        association_subject_ids: Sequence[int],
    ) -> list[AssociationSubject]:
        if not association_subject_ids:
            return []

        return await self._fetch_in_order_or_400(
            select(AssociationSubject).where(
                AssociationSubject.id.in_(association_subject_ids),
            ),
            association_subject_ids,
            error=_UNKNOWN_DISCIPLINES_ERROR,
        )

    def _assert_within_availability(
        self,
        availability: Availability,
        start_time: time,
        end_time: time,
    ) -> None:
        if start_time < availability.start_time or end_time > availability.end_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_OUTSIDE_AVAILABILITY_ERROR.format(
                    start=_format_time(availability.start_time),
                    end=_format_time(availability.end_time),
                ),
            )

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

            if start_time < presence.start_time or end_time > presence.end_time:
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
        mode: str,
        student_tax_codes: set[str],
        start_time: time,
        end_time: time,
        exclude_id: int | None,
    ) -> None:
        overlapping = await self.repository.find_overlapping_teacher_lessons(
            teacher_tax_code=availability.teacher_tax_code,
            day=availability.date,
            start_time=start_time,
            end_time=end_time,
            exclude_ids=() if exclude_id is None else (exclude_id,),
        )

        if overlaps_an_online_hour(overlapping, mode=mode):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=online_cannot_overlap_error(),
            )

        peak = peak_concurrent_students(
            spans_with(
                overlapping,
                start_time=start_time,
                end_time=end_time,
                students=len(student_tax_codes),
            ),
        )

        if peak > MAX_CONCURRENT_STUDENTS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=too_many_students_error(),
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

    async def _study_programmes_of(
        self,
        bookings: Sequence[Booking],
    ) -> set[int]:
        tax_codes = {booking.presence.student_tax_code for booking in bookings}

        if not tax_codes:
            return set()

        rows = (
            await self.session.execute(
                select(
                    SchoolEnrollment.student_tax_code,
                    SchoolEnrollment.study_program_id,
                    SchoolEnrollment.start_year,
                ).where(SchoolEnrollment.student_tax_code.in_(tax_codes)),
            )
        ).all()

        latest: dict[str, tuple[int, int]] = {}

        for student_tax_code, study_program_id, start_year in rows:
            current = latest.get(student_tax_code)

            if current is None or start_year > current[1]:
                latest[student_tax_code] = (study_program_id, start_year)

        return {programme for programme, _ in latest.values()}

    async def _disciplines_within(
        self,
        programmes: set[int],
        disciplines: Sequence[AssociationSubject],
    ) -> set[int]:
        if not programmes or not disciplines:
            return set()

        rows = await self.session.scalars(
            select(MinistryAssociationSubject.association_subject_id)
            .join(
                StudyProgramSubject,
                StudyProgramSubject.ministry_subject_id
                == MinistryAssociationSubject.ministry_subject_id,
            )
            .where(
                StudyProgramSubject.study_program_id.in_(programmes),
                MinistryAssociationSubject.association_subject_id.in_(
                    [subject.id for subject in disciplines],
                ),
            ),
        )

        return set(rows)

    async def _assert_discipline_competences(
        self,
        teacher_tax_code: str,
        disciplines: Sequence[AssociationSubject],
        bookings: Sequence[Booking],
    ) -> None:
        programmes = await self._study_programmes_of(bookings)
        within = await self._disciplines_within(programmes, disciplines)

        rows = (
            await self.session.execute(
                select(
                    TeachingCompetence.association_subject_id,
                    TeachingCompetence.study_program_id,
                ).where(
                    TeachingCompetence.teacher_tax_code == teacher_tax_code,
                    TeachingCompetence.association_subject_id.in_(
                        [subject.id for subject in disciplines],
                    ),
                ),
            )
        ).all()

        granted = {(subject_id, programme) for subject_id, programme in rows}
        any_programme = {subject_id for subject_id, _ in rows}

        lacking = sorted(
            subject.name
            for subject in disciplines
            if _lacks_competence(
                subject,
                programmes=programmes,
                within=within,
                granted=granted,
                any_programme=any_programme,
            )
        )

        if lacking:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_MISSING_COMPETENCE_ERROR.format(subjects=", ".join(lacking)),
            )

    async def _assert_service_competences(
        self,
        teacher_tax_code: str,
        bookings: Sequence[Booking],
    ) -> None:
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

        lacking = sorted(service_names - offered)

        if lacking:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_MISSING_SERVICE_ERROR.format(services=", ".join(lacking)),
            )

    async def _assert_competences(
        self,
        teacher_tax_code: str,
        disciplines: Sequence[AssociationSubject],
        bookings: Sequence[Booking],
    ) -> None:
        if disciplines:
            await self._assert_discipline_competences(
                teacher_tax_code,
                disciplines,
                bookings,
            )

            return

        await self._assert_service_competences(teacher_tax_code, bookings)

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

        unwanted = [booking for booking in bookings if booking.id in flagged]
        people = await PersonRepository(self.session).get_options(
            [
                *(booking.presence.student_tax_code for booking in unwanted),
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
            for booking in unwanted
        ]

    async def _validate(
        self,
        identity: IdentityContext,
        payload: LessonCreate | LessonUpdate,
        *,
        exclude_id: int | None,
    ) -> _ValidatedLesson:
        availability = await self._availability_or_404(payload.availability_id)

        band = assert_within_single_band(payload.start_time, payload.end_time)
        await assert_band_editable(self.session, availability.date, band)
        await assert_band_claimed(self.session, identity, availability.date, band)

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
            mode=mode,
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

        return _ValidatedLesson(
            availability=availability,
            mode=mode,
            bookings=bookings,
            disciplines=disciplines,
            warnings=warnings,
        )

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

    async def create(
        self,
        identity: IdentityContext,
        payload: LessonCreate,
    ) -> tuple[Lesson, list[str]]:
        validated = await self._validate(identity, payload, exclude_id=None)

        lesson = Lesson(
            availability=validated.availability,
            mode=validated.mode,
            start_time=payload.start_time,
            end_time=payload.end_time,
            lesson_bookings=validated.links(),
            lesson_disciplines=validated.discipline_rows(),
        )

        async with integrity_guard(self.session, _CREATE_ERROR):
            await self.repository.create(lesson)
            await self.repository.commit()

        return await self._reload(lesson.id), validated.warnings

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

        await assert_bands_editable(
            self.session,
            [(lesson.date, lesson.band)],
        )
        # The band it is leaving as well as the one it is going to, which
        # _validate takes care of: moving an hour out of an afternoon somebody
        # else is building is as much a change to that afternoon as adding one.
        await assert_bands_claimed(
            self.session,
            identity,
            [(lesson.date, lesson.band)],
        )

        validated = await self._validate(identity, payload, exclude_id=lesson.id)

        lesson.availability = validated.availability
        lesson.mode = validated.mode
        lesson.start_time = payload.start_time
        lesson.end_time = payload.end_time
        lesson.lesson_bookings = validated.links()
        lesson.lesson_disciplines = validated.discipline_rows()

        async with integrity_guard(self.session, _UPDATE_ERROR):
            await self.repository.commit()

        return await self._reload(lesson.id), validated.warnings

    async def delete(self, identity: IdentityContext, lesson_id: int) -> None:
        lesson = await self.get_visible_or_404(identity, lesson_id)

        await assert_band_editable(self.session, lesson.date, lesson.band)
        await assert_band_claimed(self.session, identity, lesson.date, lesson.band)

        await self.repository.delete(lesson)
        await self.repository.commit()

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
