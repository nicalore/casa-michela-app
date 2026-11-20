from collections.abc import Collection, Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.accounting_opening import (
    AccountingOpening,
    PupilOpening,
    TeacherOpening,
)
from app.models.member import Member
from app.models.person import GenderEnum
from app.repositories.person_repository import PersonRepository
from app.services.bilingual import Bilingual
from app.services.role_service import RoleService

# Tests run without the set-up: their fixed dates come long before money_from.
ACTIVE: bool = True

PENDING_PUPIL_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Prima configura lo studente in Contabilità › Configurazione iniziale.",
        "First set up the student in Accounting › Initial setup.",
    ),
    GenderEnum.F: Bilingual(
        "Prima configura la studentessa in Contabilità › Configurazione iniziale.",
        "First set up the student in Accounting › Initial setup.",
    ),
}


async def accounting_opening(db: AsyncSession) -> AccountingOpening | None:
    if not ACTIVE:
        return None

    return await db.get(AccountingOpening, 1)


async def money_from(db: AsyncSession) -> date | None:
    opening = await accounting_opening(db)

    return None if opening is None else opening.money_from


def day_before(first: date) -> date:
    return first - timedelta(days=1)


# The lists follow the people as they are now: enrolled and collaborating, as
# collaboration.is_collaborating reads them. Whoever stops leaves them.
async def collaborating(db: AsyncSession, tax_codes: Collection[str]) -> set[str]:
    if not tax_codes:
        return set()

    members = await db.scalars(
        select(Member)
        .options(selectinload(Member.memberships))
        .where(Member.tax_code.in_(tax_codes)),
    )

    return {
        member.tax_code
        for member in members
        if member.collaborating_active and RoleService.is_enrolled(member)
    }


@dataclass(frozen=True)
class TeacherStart:
    money_from: date | None = None
    # Pay of the days before money_from, in that month.
    gross: Decimal | None = None
    pending: bool = False


async def teacher_start(db: AsyncSession, tax_code: str) -> TeacherStart:
    first = await money_from(db)

    if first is None:
        return TeacherStart()

    row = await db.get(TeacherOpening, tax_code)

    if row is None:
        return TeacherStart(first)

    pending = row.confirmed_at is None

    # Not listed while not collaborating: nothing to wait for.
    if pending and not await collaborating(db, [tax_code]):
        return TeacherStart(first)

    return TeacherStart(first, row.gross, pending)


@dataclass(frozen=True)
class PupilStart:
    money_from: date | None = None
    opening: PupilOpening | None = None
    # Collaborating now: only then is a set-up still to do waited for.
    listed: bool = True

    @property
    def pending(self) -> bool:
        return (
            self.listed
            and self.opening is not None
            and self.opening.confirmed_at is None
        )


async def pupil_starts(
    db: AsyncSession,
    tax_codes: Sequence[str],
) -> dict[str, PupilStart]:
    first = await money_from(db)

    if first is None or not tax_codes:
        return {tax_code: PupilStart() for tax_code in tax_codes}

    rows = {
        row.tax_code: row
        for row in await db.scalars(
            select(PupilOpening).where(PupilOpening.tax_code.in_(tax_codes)),
        )
    }
    active = await collaborating(
        db,
        [code for code, row in rows.items() if row.confirmed_at is None],
    )

    return {
        tax_code: PupilStart(
            first,
            rows.get(tax_code),
            rows.get(tax_code) is None
            or rows[tax_code].confirmed_at is not None
            or tax_code in active,
        )
        for tax_code in tax_codes
    }


async def pupil_start(db: AsyncSession, tax_code: str) -> PupilStart:
    return (await pupil_starts(db, [tax_code]))[tax_code]


# Until the set-up says how the pupil stood, nothing is bought or settled by the hour.
async def refuse_pending_pupil(db: AsyncSession, tax_code: str) -> None:
    if (await pupil_start(db, tax_code)).pending:
        gender = await PersonRepository(db).gender(tax_code)

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=PENDING_PUPIL_ERRORS[gender].for_request(),
        )
