from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.schemas.accounting_opening import (
    AccountingOpeningResponse,
    OpeningPupilResponse,
    OpeningTeacherResponse,
    PupilOpeningData,
    TeacherOpeningData,
)
from app.services.accounting_lock import lock_account
from app.services.accounting_opening import (
    close_opening,
    confirm_pupil,
    confirm_teacher,
    opening_or_404,
    pupil_listed,
    pupils_listed,
    teachers_listed,
)

router = APIRouter(prefix="/accounting/opening", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]

# Every write of the set-up waits for the others, then for the person's account.
_OPENING_LOCK = "opening"


async def _whole(db: DbSession) -> AccountingOpeningResponse:
    opening = await opening_or_404(db)

    return AccountingOpeningResponse(
        money_from=opening.money_from,
        closed=opening.closed_at is not None,
        teachers=await teachers_listed(db, opening),
        pupils=await pupils_listed(db, opening),
    )


@router.get("/", response_model=AccountingOpeningResponse)
async def get_opening(db: DbSession, _: Admin) -> AccountingOpeningResponse:
    return await _whole(db)


@router.get("/pupils/{tax_code}", response_model=OpeningPupilResponse)
async def get_pupil(tax_code: str, db: DbSession, _: Admin) -> OpeningPupilResponse:
    return await pupil_listed(db, await opening_or_404(db), tax_code.upper())


@router.put("/teachers/{tax_code}", response_model=OpeningTeacherResponse)
async def put_teacher(
    tax_code: str,
    payload: TeacherOpeningData,
    db: DbSession,
    identity: Admin,
) -> OpeningTeacherResponse:
    await lock_account(db, _OPENING_LOCK)
    await lock_account(db, tax_code.upper())
    opening = await opening_or_404(db)
    teacher = await confirm_teacher(
        db,
        opening,
        tax_code.upper(),
        payload,
        identity.tax_code,
    )
    await db.commit()

    return teacher


@router.put("/pupils/{tax_code}", response_model=OpeningPupilResponse)
async def put_pupil(
    tax_code: str,
    payload: PupilOpeningData,
    db: DbSession,
    identity: Admin,
) -> OpeningPupilResponse:
    await lock_account(db, _OPENING_LOCK)
    await lock_account(db, tax_code.upper())
    opening = await opening_or_404(db)
    pupil = await confirm_pupil(
        db,
        opening,
        tax_code.upper(),
        payload,
        identity.tax_code,
    )
    await db.commit()

    return pupil


# Once every teacher and pupil listed is confirmed: the set-up goes for good.
@router.post("/close", response_model=AccountingOpeningResponse)
async def close(db: DbSession, identity: Admin) -> AccountingOpeningResponse:
    await lock_account(db, _OPENING_LOCK)
    await close_opening(db, await opening_or_404(db), identity.tax_code)
    await db.commit()

    return await _whole(db)
