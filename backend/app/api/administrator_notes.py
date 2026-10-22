from typing import Annotated, Final

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.models.administrator_note import AdministratorNote
from app.schemas.student_note import StudentNoteResponse
from app.services import push
from app.services.administrator_note_notifications import (
    administrator_note_deleted,
    announce_administrator_note,
)
from app.services.student_notes import (
    NoteImages,
    NoteText,
    administrator_note_image,
    load_note,
    note_of_teacher,
    note_response,
    settle_note_images,
    teacher_or_404,
)

_FORBIDDEN_ERROR: Final[str] = "Non hai accesso ai dati di questa persona."

# Administrators only, and any of them may change or delete any note.
router = APIRouter(prefix="/people/{tax_code}/administrator-notes", tags=["people"])

Administrator = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=StudentNoteResponse,
)
async def create_administrator_note(
    tax_code: str,
    text: NoteText,
    identity: Administrator,
    db: DbSession,
    background: BackgroundTasks,
    images: NoteImages = None,
) -> StudentNoteResponse:
    teacher = await teacher_or_404(db, tax_code)

    note = AdministratorNote(
        teacher_tax_code=teacher.tax_code,
        author_tax_code=identity.tax_code,
        text=text,
    )
    await settle_note_images(db, note, images)
    db.add(note)
    batch = await announce_administrator_note(db, note)
    await db.commit()
    background.add_task(push.deliver, batch)

    return note_response(await load_note(db, AdministratorNote, note.id))


# Not told again: the teacher reads the note as it now is.
@router.put("/{note_id}", response_model=StudentNoteResponse)
async def update_administrator_note(
    tax_code: str,
    note_id: int,
    text: NoteText,
    _: Administrator,
    db: DbSession,
    images: NoteImages = None,
) -> StudentNoteResponse:
    note = await note_of_teacher(
        db,
        teacher_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    note.text = text
    await settle_note_images(db, note, images)
    await db.commit()

    return note_response(await load_note(db, AdministratorNote, note_id))


# The administrators, and the teacher the note is about.
@router.get("/{note_id}/images/{image_key}")
async def get_administrator_note_image(
    tax_code: str,
    note_id: int,
    image_key: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> Response:
    code = tax_code.upper()

    if not (identity.is_admin or identity.tax_code == code):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_FORBIDDEN_ERROR,
        )

    image = await administrator_note_image(
        db,
        teacher_tax_code=code,
        note_id=note_id,
        image_key=image_key,
    )

    return Response(content=image.content, media_type=image.content_type)


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_administrator_note(
    tax_code: str,
    note_id: int,
    _: Administrator,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    note = await note_of_teacher(
        db,
        teacher_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    batch = await administrator_note_deleted(db, note.id)
    await db.delete(note)
    await db.commit()
    background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)
