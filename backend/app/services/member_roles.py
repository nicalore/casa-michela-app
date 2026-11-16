from collections import defaultdict
from collections.abc import Collection
from typing import Final

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator import Administrator
from app.models.course_participant import CourseParticipant
from app.models.parent import Parent
from app.models.psychologist import Psychologist
from app.models.student import Student
from app.models.teacher import Teacher

# The roles accounting lists filter by, as the role tables hold them.
_ROLE_TABLES: Final = (
    ("STUDENTE", Student.tax_code),
    ("DOCENTE", Teacher.tax_code),
    ("CORSISTA", CourseParticipant.tax_code),
    ("GENITORE", Parent.tax_code),
    ("AMMINISTRATORE", Administrator.tax_code),
    ("PSICOLOGO", Psychologist.tax_code),
)


async def roles_of(
    db: AsyncSession,
    tax_codes: Collection[str],
) -> dict[str, tuple[str, ...]]:
    """Every role each person holds, in a fixed order; none for nobody."""
    found: dict[str, list[str]] = defaultdict(list)

    if not tax_codes:
        return {}

    for role, column in _ROLE_TABLES:
        for tax_code in await db.scalars(select(column).where(column.in_(tax_codes))):
            found[tax_code].append(role)

    return {tax_code: tuple(found[tax_code]) for tax_code in tax_codes}
