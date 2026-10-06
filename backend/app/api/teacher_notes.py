from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.models.teacher_note import TeacherNote
from app.schemas.student_note import TeacherNoteCreate
from app.services.student_notes import note_of_student
from app.services.teacher_notes import write_teacher_note

# Written by the teacher after the lesson; only administrators read or delete it.
router = APIRouter(tags=["people"])

Teacher = Annotated[IdentityContext, Depends(require_role("TEACHER"))]
Administrator = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


@router.post(
    "/lessons/{lesson_id}/teacher-notes/",
    status_code=status.HTTP_201_CREATED,
)
async def create_teacher_note(
    lesson_id: int,
    payload: TeacherNoteCreate,
    identity: Teacher,
    db: DbSession,
) -> dict[str, int]:
    note = await write_teacher_note(
        db,
        teacher_tax_code=identity.tax_code,
        lesson_id=lesson_id,
        payload=payload,
    )
    await db.commit()

    return {"id": note.id}


@router.delete(
    "/people/{tax_code}/teacher-notes/{note_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_teacher_note(
    tax_code: str,
    note_id: int,
    _: Administrator,
    db: DbSession,
) -> Response:
    note = await note_of_student(
        db,
        TeacherNote,
        student_tax_code=tax_code.upper(),
        note_id=note_id,
    )

    await db.delete(note)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
