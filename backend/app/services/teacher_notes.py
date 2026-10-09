from datetime import datetime
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.booking_window import now_in_rome
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.ministry_subject import MinistrySubject
from app.models.teacher_note import TeacherNote
from app.schemas.student_note import StudentNoteWrite, TeacherNoteResponse

_LESSON_NOT_FOUND_ERROR: Final[str] = "Lezione non trovata"
_BOOKING_NOT_FOUND_ERROR: Final[str] = "Prenotazione non trovata"
_NOT_THEIR_LESSON_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"
_NOT_STARTED_ERROR: Final[str] = "La lezione non è ancora iniziata."

# The frontend's fallback for a ministry subject it cannot name.
_UNNAMED_SUBJECT: Final[str] = "Materia"


def teacher_note_response(note: TeacherNote) -> TeacherNoteResponse:
    return TeacherNoteResponse(
        id=note.id,
        text=note.text,
        author_tax_code=note.author_tax_code,
        author_name=f"{note.author.first_name} {note.author.last_name}",
        created_at=note.created_at,
        lesson_date=note.lesson_date,
        subject=note.subject,
    )


async def _subject_of(db: AsyncSession, booking: Booking) -> str:
    if booking.service_name is not None:
        return booking.service_name

    if booking.association_subject is not None:
        return booking.association_subject.name

    for requested in booking.subjects_requested:
        subject = await db.get(MinistrySubject, requested.ministry_subject_id)

        if subject is not None:
            return subject.name

    return _UNNAMED_SUBJECT


async def write_teacher_note(
    db: AsyncSession,
    *,
    teacher_tax_code: str,
    lesson_id: int,
    payload: StudentNoteWrite,
) -> TeacherNote:
    booking_load = joinedload(Lesson.lesson_bookings).joinedload(LessonBooking.booking)
    stmt = (
        select(Lesson)
        .options(
            joinedload(Lesson.availability),
            booking_load.joinedload(Booking.presence),
            booking_load.joinedload(Booking.association_subject),
            booking_load.selectinload(Booking.subjects_requested),
        )
        .where(Lesson.id == lesson_id)
    )
    lesson = (await db.execute(stmt)).unique().scalar_one_or_none()

    if lesson is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_LESSON_NOT_FOUND_ERROR,
        )

    if lesson.availability.teacher_tax_code != teacher_tax_code:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_NOT_THEIR_LESSON_ERROR,
        )

    starts = datetime.combine(lesson.date, lesson.start_time)

    if starts > now_in_rome().replace(tzinfo=None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NOT_STARTED_ERROR,
        )

    bookings = [link.booking for link in lesson.lesson_bookings]

    if not bookings:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_BOOKING_NOT_FOUND_ERROR,
        )

    # The note is about the whole lesson: every subject in it, each named once.
    subjects = dict.fromkeys([await _subject_of(db, booking) for booking in bookings])

    note = TeacherNote(
        student_tax_code=bookings[0].presence.student_tax_code,
        author_tax_code=teacher_tax_code,
        lesson_id=lesson.id,
        lesson_date=lesson.date,
        subject=", ".join(subjects),
        text=payload.text,
    )
    db.add(note)

    return note

