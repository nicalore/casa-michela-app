from collections.abc import Iterable
from decimal import Decimal

from app.models.teacher import CRITERION_POINTS, TEACHER_CRITERIA


# Half a point per criterion met; nothing while the teacher does not collaborate.
def teacher_rating(met_criteria: Iterable[str], *, collaborating: bool) -> Decimal:
    if not collaborating:
        return Decimal(0)

    return CRITERION_POINTS * len(set(met_criteria))


# In the list's own order, each once.
def ordered_criteria(met_criteria: Iterable[str]) -> list[str]:
    met = set(met_criteria)

    return [key for key in TEACHER_CRITERIA if key in met]
