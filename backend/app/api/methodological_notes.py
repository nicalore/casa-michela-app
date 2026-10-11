from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.models.methodological_note import MethodologicalNote
from app.schemas.student_note import StudentNoteResponse
from app.services.methodological_notes import followed_student, own_note
from app.services.student_notes import (
    NoteImages,
    NoteText,
    check_note_reader,
    load_note,
    note_image,
    note_response,
    settle_note_images,
)

router = APIRouter(prefix="/people/{tax_code}/methodological-notes", tags=["people"])

Psychologist = Annotated[IdentityContext, Depends(require_role("PSYCHOLOGIST"))]


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=StudentNoteResponse,
)
async def create_methodological_note(
    tax_code: str,
    text: NoteText,
    identity: Psychologist,
    db: DbSession,
    images: NoteImages = None,
) -> StudentNoteResponse:
    student = await followed_student(db, tax_code)

    note = MethodologicalNote(
        student_tax_code=student.tax_code,
        author_tax_code=identity.tax_code,
        text=text,
    )
    await settle_note_images(db, note, images)
    db.add(note)
    await db.commit()

    return note_response(await load_note(db, MethodologicalNote, note.id))


@router.put("/{note_id}", response_model=StudentNoteResponse)
async def update_methodological_note(
    tax_code: str,
    note_id: int,
    text: NoteText,
    identity: Psychologist,
    db: DbSession,
    images: NoteImages = None,
) -> StudentNoteResponse:
    student = await followed_student(db, tax_code)
    note = await own_note(
        db,
        author_tax_code=identity.tax_code,
        student_tax_code=student.tax_code,
        note_id=note_id,
    )

    note.text = text
    await settle_note_images(db, note, images)
    await db.commit()

    return note_response(await load_note(db, MethodologicalNote, note_id))


@router.get("/{note_id}/images/{image_key}")
async def get_methodological_note_image(
    tax_code: str,
    note_id: int,
    image_key: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> Response:
    code = tax_code.upper()
    await check_note_reader(db, identity, code, methodological=True)
    image = await note_image(
        db,
        MethodologicalNote,
        student_tax_code=code,
        note_id=note_id,
        image_key=image_key,
    )

    return Response(content=image.content, media_type=image.content_type)


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
