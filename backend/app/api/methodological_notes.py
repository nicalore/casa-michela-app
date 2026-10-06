from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.models.methodological_note import MethodologicalNote
from app.schemas.student_note import StudentNoteResponse, StudentNoteWrite
from app.services.methodological_notes import followed_student, own_note
from app.services.student_notes import load_note, note_response

router = APIRouter(prefix="/people/{tax_code}/methodological-notes", tags=["people"])

Psychologist = Annotated[IdentityContext, Depends(require_role("PSYCHOLOGIST"))]


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=StudentNoteResponse,
)
async def create_methodological_note(
    tax_code: str,
    payload: StudentNoteWrite,
    identity: Psychologist,
    db: DbSession,
) -> StudentNoteResponse:
    student = await followed_student(db, tax_code)

    note = MethodologicalNote(
        student_tax_code=student.tax_code,
        author_tax_code=identity.tax_code,
        text=payload.text,
    )
    db.add(note)
    await db.commit()

    return note_response(await load_note(db, MethodologicalNote, note.id))


@router.put("/{note_id}", response_model=StudentNoteResponse)
async def update_methodological_note(
    tax_code: str,
    note_id: int,
    payload: StudentNoteWrite,
    identity: Psychologist,
    db: DbSession,
) -> StudentNoteResponse:
    student = await followed_student(db, tax_code)
    note = await own_note(
        db,
        author_tax_code=identity.tax_code,
        student_tax_code=student.tax_code,
        note_id=note_id,
    )

    note.text = payload.text
    await db.commit()

    return note_response(await load_note(db, MethodologicalNote, note_id))


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_methodological_note(
    tax_code: str,
    note_id: int,
    identity: Psychologist,
    db: DbSession,
) -> Response:
    student = await followed_student(db, tax_code)
    note = await own_note(
        db,
        author_tax_code=identity.tax_code,
        student_tax_code=student.tax_code,
        note_id=note_id,
    )

    await db.delete(note)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
