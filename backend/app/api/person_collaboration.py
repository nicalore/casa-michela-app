from dataclasses import asdict
from datetime import UTC, datetime
from typing import Final

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import DbSession
from app.api.rbac import require_role
from app.models.member import Member
from app.schemas.person_collaboration import CollaborationUpdate
from app.services.calendar_hours_sync import LOST_ERROR
from app.services.collaboration import count_hours_ahead, stop_collaboration
from app.services.role_service import RoleService

router = APIRouter(
    prefix="/people/{tax_code}/collaboration",
    tags=["people"],
    dependencies=[Depends(require_role("ADMIN"))],
)

_MEMBER_NOT_FOUND_ERROR: Final[str] = "L'utente non possiede un profilo da associato."
_NOT_ENROLLED_ERROR: Final[str] = (
    "Impossibile impostare \"Collaboratore attivo\" senza un'iscrizione in corso."
)


async def _member_or_404(db: AsyncSession, tax_code: str) -> Member:
    member = await db.scalar(
        select(Member)
        .options(selectinload(Member.memberships))
        .where(Member.tax_code == tax_code.upper()),
    )

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_MEMBER_NOT_FOUND_ERROR,
        )

    return member


# Sets the wanted state, so a repeated click or a sweep in between changes nothing.
@router.put("", status_code=status.HTTP_204_NO_CONTENT)
async def set_collaboration(
    tax_code: str,
    payload: CollaborationUpdate,
    db: DbSession,
) -> None:
    member = await _member_or_404(db, tax_code)

    if payload.active == member.collaborating_active:
        return

    if payload.active:
        # A revocation ends the enrollment too, so it is refused here as well.
        if not RoleService.is_enrolled(member):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_ENROLLED_ERROR,
            )

        member.collaborating_active = True
    else:
        if not payload.confirm:
            hours = await count_hours_ahead(db, member.tax_code)

            if hours:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={"error": LOST_ERROR, "hours": asdict(hours)},
                )

        await stop_collaboration(db, member)

    member.updated_at = datetime.now(UTC)

    await db.commit()
