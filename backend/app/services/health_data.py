from sqlalchemy import delete, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.member import Member
from app.models.methodological_note import MethodologicalNote
from app.models.psychological_support import PsychologicalSupport
from app.models.student import Student


# Withdrawn consent: the special categories go, images with their notes.
async def erase_health_data(db: AsyncSession, tax_code: str) -> None:
    await db.execute(
        update(Member)
        .where(Member.tax_code == tax_code)
        .values(allergies_notes=None, medications_notes=None)
    )
    await db.execute(
        update(Student)
        .where(Student.tax_code == tax_code)
        .values(
            certification_types=[],
            certification_other_detail=None,
            certification_dsa_detail=None,
            mandatory_psych_meetings_acknowledged=False,
        )
    )
    await db.execute(
        delete(PsychologicalSupport).where(PsychologicalSupport.tax_code == tax_code)
    )
    await db.execute(
        delete(MethodologicalNote).where(
            MethodologicalNote.student_tax_code == tax_code
        )
    )
