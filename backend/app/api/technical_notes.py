from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.models.technical_note import TechnicalNote
from app.schemas.student_note import StudentNoteResponse
from app.services.student_notes import (
    NoteImages,
    NoteText,
    check_note_reader,
    load_note,
    note_image,
    note_of_student,
    note_response,
    settle_note_images,
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
    text: NoteText,
    identity: Administrator,
    db: DbSession,
    images: NoteImages = None,
) -> StudentNoteResponse:
    student = await student_or_404(db, tax_code)

    note = TechnicalNote(
        student_tax_code=student.tax_code,
        author_tax_code=identity.tax_code,
        text=text,
    )
    await settle_note_images(db, note, images)
    db.add(note)
    await db.commit()

    return note_response(await load_note(db, TechnicalNote, note.id))


@router.put("/{note_id}", response_model=StudentNoteResponse)
async def update_technical_note(
    tax_code: str,
    note_id: int,
    text: NoteText,
    _: Administrator,
    db: DbSession,
    images: NoteImages = None,
) -> StudentNoteResponse:
    note = await note_of_student(
        db,
        TechnicalNote,
        student_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    note.text = text
    await settle_note_images(db, note, images)
    await db.commit()

    return note_response(await load_note(db, TechnicalNote, note_id))


@router.get("/{note_id}/images/{image_key}")
async def get_technical_note_image(
    tax_code: str,
    note_id: int,
    image_key: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> Response:
    code = tax_code.upper()
    await check_note_reader(db, identity, code, methodological=False)
    image = await note_image(
        db,
        TechnicalNote,
        student_tax_code=code,
        note_id=note_id,
        image_key=image_key,
    )

    return Response(content=image.content, media_type=image.content_type)


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
