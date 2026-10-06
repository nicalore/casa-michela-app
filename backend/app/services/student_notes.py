from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.methodological_note import MethodologicalNote
from app.models.student import Student
from app.models.teacher_note import TeacherNote
from app.models.technical_note import TechnicalNote
from app.schemas.student_note import StudentNoteResponse

_PERSON_NOT_FOUND_ERROR: Final[str] = "Persona non trovata"
_NOTE_NOT_FOUND_ERROR: Final[str] = "Osservazione non trovata"

StudentNote = MethodologicalNote | TechnicalNote

AnyNote = StudentNote | TeacherNote


def note_response(note: StudentNote) -> StudentNoteResponse:
    return StudentNoteResponse(
        id=note.id,
        text=note.text,
        author_tax_code=note.author_tax_code,
        author_name=f"{note.author.first_name} {note.author.last_name}",
        created_at=note.created_at,
        updated_at=note.updated_at,
    )


async def student_or_404(db: AsyncSession, tax_code: str) -> Student:
    student = await db.get(Student, tax_code.upper())

    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return student


async def note_of_student[N: AnyNote](
    db: AsyncSession,
    model: type[N],
    *,
    student_tax_code: str,
    note_id: int,
) -> N:
    note = await db.get(model, note_id)

    if note is None or note.student_tax_code != student_tax_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOTE_NOT_FOUND_ERROR,
        )

    return note


async def load_note[N: StudentNote](db: AsyncSession, model: type[N], note_id: int) -> N:
    stmt = select(model).options(joinedload(model.author)).where(model.id == note_id)

    return (await db.execute(stmt)).unique().scalar_one()
