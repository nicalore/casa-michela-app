from typing import Annotated, Final

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.models.member import Member
from app.models.teacher import TEACHER_CRITERIA, Teacher
from app.schemas.teacher_evaluation import CriterionUpdate, TeacherEvaluationResponse
from app.services import push
from app.services.rating_reminders import rating_updated
from app.services.teacher_evaluation import ordered_criteria, teacher_rating

_TEACHER_NOT_FOUND_ERROR: Final[str] = "Docente non trovato"
_UNKNOWN_CRITERION_ERROR: Final[str] = "Criterio di valutazione sconosciuto."
_NOT_COLLABORATING_ERROR: Final[str] = (
    "Non è possibile valutare un docente non collaborante."
)

# Administrators only, and any of them may judge any teacher.
router = APIRouter(prefix="/people/{tax_code}/evaluation", tags=["people"])

Administrator = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


# One criterion at a time: two administrators ticking different ones lose nothing.
@router.put("/{criterion}", response_model=TeacherEvaluationResponse)
async def set_criterion(
    tax_code: str,
    criterion: str,
    payload: CriterionUpdate,
    _: Administrator,
    db: DbSession,
    background: BackgroundTasks,
) -> TeacherEvaluationResponse:
    if criterion not in TEACHER_CRITERIA:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_UNKNOWN_CRITERION_ERROR,
        )

    teacher = await db.scalar(
        select(Teacher).where(Teacher.tax_code == tax_code.upper()).with_for_update()
    )

    if teacher is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_TEACHER_NOT_FOUND_ERROR,
        )

    collaborating = bool(
        await db.scalar(
            select(Member.collaborating_active).where(
                Member.tax_code == teacher.tax_code
            )
        )
    )

    # Worth nothing meanwhile: the ticks wait as they were for a return.
    if not collaborating:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_NOT_COLLABORATING_ERROR,
        )

    met = set(teacher.met_criteria)
    wanted = met | {criterion} if payload.met else met - {criterion}
    batch = push.joined([])

    if wanted != met:
        teacher.met_criteria = ordered_criteria(wanted)
        batch = await rating_updated(db, teacher.tax_code)

    await db.commit()
    background.add_task(push.deliver, batch)

    return TeacherEvaluationResponse(
        met_criteria=list(teacher.met_criteria),
        rating=float(teacher_rating(teacher.met_criteria, collaborating=True)),
    )
