from fastapi import APIRouter, Depends, status

from app.api.dependencies import DbSession
from app.api.rbac import require_role
from app.core.booking_window import now_in_rome
from app.schemas.re_enrollment import ReEnrollmentPayload
from app.services.accounting_lock import lock_account
from app.services.re_enrollment import re_enroll

router = APIRouter(
    prefix="/people/{tax_code}/re-enrollment",
    tags=["people"],
    dependencies=[Depends(require_role("ADMIN"))],
)


# The year in course, its fees and, for a pupil, the tariff: all or nothing.
@router.post("", status_code=status.HTTP_204_NO_CONTENT)
async def re_enroll_person(
    tax_code: str,
    payload: ReEnrollmentPayload,
    db: DbSession,
) -> None:
    await lock_account(db, tax_code.upper())

    # A refusal halfway leaves nothing behind.
    async with db.begin_nested():
        await re_enroll(db, tax_code.upper(), payload, now_in_rome())

    await db.commit()
