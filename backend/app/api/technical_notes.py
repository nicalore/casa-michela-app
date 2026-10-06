from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.models.technical_note import TechnicalNote
from app.schemas.student_note import StudentNoteResponse, StudentNoteWrite
from app.services.student_notes import (
    load_note,
    note_of_student,
    note_response,
    student_or_404,
)

# Administrators only, and any of them may change or delete any note.
router = APIRouter(prefix="/people/{tax_code}/technical-notes", tags=["people"])

Administrator = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=StudentNoteResponse,
)
async def create_technical_note(
    tax_code: str,
    payload: StudentNoteWrite,
    identity: Administrator,
    db: DbSession,
) -> StudentNoteResponse:
    student = await student_or_404(db, tax_code)

    note = TechnicalNote(
        student_tax_code=student.tax_code,
        author_tax_code=identity.tax_code,
        text=payload.text,
    )
    db.add(note)
    await db.commit()

    return note_response(await load_note(db, TechnicalNote, note.id))


@router.put("/{note_id}", response_model=StudentNoteResponse)
async def update_technical_note(
    tax_code: str,
    note_id: int,
    payload: StudentNoteWrite,
    _: Administrator,
    db: DbSession,
) -> StudentNoteResponse:
    note = await note_of_student(
        db,
        TechnicalNote,
        student_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    note.text = payload.text
    await db.commit()

    return note_response(await load_note(db, TechnicalNote, note_id))


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_technical_note(
    tax_code: str,
    note_id: int,
    _: Administrator,
    db: DbSession,
) -> Response:
    note = await note_of_student(
        db,
        TechnicalNote,
        student_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    await db.delete(note)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
