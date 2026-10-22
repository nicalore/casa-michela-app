from collections.abc import Sequence
from typing import Annotated, Final

from fastapi import File, Form, HTTPException, UploadFile, status
from sqlalchemy import ColumnElement, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload, undefer

from app.api.rbac import IdentityContext
from app.core import field_lengths
from app.core.booking_window import today_in_rome
from app.models.administrator_note import AdministratorNote
from app.models.member import Member
from app.models.methodological_note import MethodologicalNote
from app.models.student import Student
from app.models.student_note_image import StudentNoteImage
from app.models.teacher import Teacher
from app.models.teacher_note import TeacherNote
from app.models.technical_note import TechnicalNote
from app.repositories.lesson_repository import LessonRepository
from app.schemas.student_note import StudentNoteImageResponse, StudentNoteResponse
from app.schemas.validators import CleanStr
from app.services.notices import Upload, read_uploads, settle_images
from app.services.role_service import RoleService

_PERSON_NOT_FOUND_ERROR: Final[str] = "Persona non trovata"
_NOTE_NOT_FOUND_ERROR: Final[str] = "Osservazione non trovata"
_IMAGE_NOT_FOUND_ERROR: Final[str] = "Immagine non trovata"
_FORBIDDEN_ERROR: Final[str] = "Non hai accesso ai dati di questa persona."
_TOO_LARGE_ERROR: Final[str] = "Le immagini superano i 15 MB totali."

StudentNote = MethodologicalNote | TechnicalNote

AnyNote = StudentNote | TeacherNote

# Markdown with images, as a notice's message.
RichNote = StudentNote | AdministratorNote

# Sent as a form, with the images the text shows named by their keys.
NoteText = Annotated[
    CleanStr,
    Form(min_length=1, max_length=field_lengths.STUDENT_NOTE_MARKDOWN),
]

NoteImages = Annotated[list[UploadFile] | None, File()]


# On the register: the pupils teachers may read.
def is_enrolled_pupil(member: Member | None) -> bool:
    return (
        member is not None
        and member.student_profile is not None
        and RoleService.is_enrolled(member)
    )


# Psychologists keep health data: only pupils who consented to it.
def is_followed(member: Member | None) -> bool:
    return (
        member is not None
        and is_enrolled_pupil(member)
        and member.special_category_data_consent
    )


def note_response(note: RichNote) -> StudentNoteResponse:
    return StudentNoteResponse(
        id=note.id,
        text=note.text,
        author_tax_code=note.author_tax_code,
        author_name=f"{note.author.first_name} {note.author.last_name}",
        created_at=note.created_at,
        updated_at=note.updated_at,
        images=[
            StudentNoteImageResponse(key=image.image_key, size=image.size)
            for image in note.images
        ],
    )


async def student_or_404(db: AsyncSession, tax_code: str) -> Student:
    student = await db.get(Student, tax_code.upper())

    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return student


async def teacher_or_404(db: AsyncSession, tax_code: str) -> Teacher:
    teacher = await db.get(Teacher, tax_code.upper())

    if teacher is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    return teacher


async def note_of_teacher(
    db: AsyncSession,
    *,
    teacher_tax_code: str,
    note_id: int,
) -> AdministratorNote:
    note = await db.get(AdministratorNote, note_id)

    if note is None or note.teacher_tax_code != teacher_tax_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOTE_NOT_FOUND_ERROR,
        )

    return note


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


async def load_note[N: RichNote](db: AsyncSession, model: type[N], note_id: int) -> N:
    stmt = (
        select(model)
        .options(joinedload(model.author), selectinload(model.images))
        .where(model.id == note_id)
        .execution_options(populate_existing=True)
    )

    return (await db.execute(stmt)).unique().scalar_one()


def _stored(upload: Upload, image_key: str) -> StudentNoteImage:
    return StudentNoteImage(
        image_key=image_key,
        content_type=upload.content_type,
        size=len(upload.content),
        content=upload.content,
    )


# The images the text shows: those kept, then the new ones; the others go.
async def settle_note_images(
    db: AsyncSession,
    note: RichNote,
    uploads: Sequence[UploadFile] | None,
) -> None:
    if note.id is not None:
        await db.refresh(note, ["images"])

    kept, added = settle_images(
        note.text,
        {image.image_key: image for image in note.images},
        await read_uploads(uploads, too_large=_TOO_LARGE_ERROR),
        _stored,
    )
    note.images = [*kept, *added]


# Whoever is sent the notes with the pupil's record: see get_person in api/people.
async def check_note_reader(
    db: AsyncSession,
    identity: IdentityContext,
    student_tax_code: str,
    *,
    methodological: bool,
) -> None:
    if identity.is_admin and not methodological:
        return

    member = await db.scalar(
        select(Member)
        .options(
            selectinload(Member.memberships),
            joinedload(Member.student_profile),
        )
        .where(Member.tax_code == student_tax_code)
    )

    # Methodological notes are health data: without the consent nobody opens them.
    consented = member is not None and member.special_category_data_consent

    if identity.is_admin and consented:
        return

    if methodological and not consented:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_FORBIDDEN_ERROR,
        )

    if methodological and "PSYCHOLOGIST" in identity.roles and is_followed(member):
        return

    if (
        "TEACHER" in identity.roles
        and is_enrolled_pupil(member)
        and await LessonRepository(db).has_paired(
            identity.tax_code,
            student_tax_code,
            since=today_in_rome(),
        )
    ):
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=_FORBIDDEN_ERROR,
    )


async def note_image(
    db: AsyncSession,
    model: type[StudentNote],
    *,
    student_tax_code: str,
    note_id: int,
    image_key: str,
) -> StudentNoteImage:
    await note_of_student(
        db,
        model,
        student_tax_code=student_tax_code,
        note_id=note_id,
    )

    owner = (
        StudentNoteImage.technical_note_id
        if model is TechnicalNote
        else StudentNoteImage.methodological_note_id
    )

    return await _image(db, owner == note_id, image_key)


async def administrator_note_image(
    db: AsyncSession,
    *,
    teacher_tax_code: str,
    note_id: int,
    image_key: str,
) -> StudentNoteImage:
    await note_of_teacher(db, teacher_tax_code=teacher_tax_code, note_id=note_id)

    return await _image(
        db,
        StudentNoteImage.administrator_note_id == note_id,
        image_key,
    )


async def _image(
    db: AsyncSession,
    owned: ColumnElement[bool],
    image_key: str,
) -> StudentNoteImage:
    image = await db.scalar(
        select(StudentNoteImage)
        .options(undefer(StudentNoteImage.content))
        .where(owned, StudentNoteImage.image_key == image_key)
    )

    if image is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_IMAGE_NOT_FOUND_ERROR,
        )

    return image
