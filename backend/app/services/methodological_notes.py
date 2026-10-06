from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.member import Member
from app.models.methodological_note import MethodologicalNote
from app.models.student import Student
from app.services.role_service import RoleService
from app.services.student_notes import note_of_student

_PERSON_NOT_FOUND_ERROR: Final[str] = "Persona non trovata"
_PERSON_FORBIDDEN_ERROR: Final[str] = "Non hai accesso ai dati di questa persona."
_NOT_THE_AUTHOR_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"


# The pupils a psychologist follows: those on the register.
def is_followed(member: Member | None) -> bool:
    return (
        member is not None
        and member.student_profile is not None
        and RoleService.is_enrolled(member)
    )


async def followed_student(db: AsyncSession, tax_code: str) -> Student:
    stmt = (
        select(Student)
        .options(
            joinedload(Student.member).selectinload(Member.memberships),
            joinedload(Student.member).joinedload(Member.student_profile),
        )
        .where(Student.tax_code == tax_code.upper())
    )
    student = (await db.execute(stmt)).unique().scalar_one_or_none()

    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    if not is_followed(student.member):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_PERSON_FORBIDDEN_ERROR,
        )

    return student


# Every psychologist reads every note; only its author changes or deletes it.
async def own_note(
    db: AsyncSession,
    *,
    author_tax_code: str,
    student_tax_code: str,
    note_id: int,
) -> MethodologicalNote:
    note = await note_of_student(
        db,
        MethodologicalNote,
        student_tax_code=student_tax_code,
        note_id=note_id,
    )

    if note.author_tax_code != author_tax_code:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_NOT_THE_AUTHOR_ERROR,
        )

    return note
