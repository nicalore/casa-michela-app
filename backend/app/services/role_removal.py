from dataclasses import dataclass
from typing import Any, Final

from fastapi import HTTPException, status
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.confirmed_hours import ConfirmedHours
from app.models.payment_receipt import PaymentReceipt
from app.models.student_hours import StudentConfirmedHours
from app.models.student_payment import StudentPayment
from app.services.collaboration import (
    count_hours_ahead,
    drop_hours_ahead,
    has_begun_hours,
)
from app.services.write_losses import Losses

# A role is taken away only to fix a mistake: once it has a history it stays,
# and the person stops through the collaboration, a lapse or a revocation.
_HISTORY_ERROR: Final[str] = (
    "Impossibile togliere il ruolo {role}: ci sono lezioni, ore o pagamenti "
    "registrati."
)

_TEACHING_AHEAD: Final[str] = (
    "Togliendo il ruolo Docente, le sue disponibilità non ancora iniziate "
    "verranno eliminate definitivamente."
)
_TEACHING_LESSONS: Final[str] = (
    " Le lezioni già pianificate verranno tolte dal calendario e dovranno essere "
    "nuovamente pianificate."
)
_LEARNING_AHEAD: Final[str] = (
    "Togliendo il ruolo Studente, le sue presenze non ancora iniziate verranno "
    "eliminate definitivamente, insieme alle prenotazioni{lessons}."
)
_LEARNING_LESSONS: Final[str] = " e alle lezioni già pianificate"


def _refused(role: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=_HISTORY_ERROR.format(role=role),
    )


async def _any(db: AsyncSession, query: Select[tuple[Any]]) -> bool:
    return (await db.scalar(query.limit(1))) is not None


async def _taught(db: AsyncSession, tax_code: str) -> bool:
    return await has_begun_hours(db, tax_code, teaching=True) or await _any(
        db,
        select(ConfirmedHours.id).where(ConfirmedHours.teacher_tax_code == tax_code),
    )


async def _learnt(db: AsyncSession, tax_code: str) -> bool:
    return (
        await has_begun_hours(db, tax_code, teaching=False)
        or await _any(
            db,
            select(StudentConfirmedHours.id).where(
                StudentConfirmedHours.student_tax_code == tax_code,
            ),
        )
        or await _any(
            db,
            select(StudentPayment.id).where(
                StudentPayment.student_tax_code == tax_code,
            ),
        )
    )


async def _paid_staff(db: AsyncSession, tax_code: str) -> bool:
    return await _any(
        db,
        select(PaymentReceipt.month).where(PaymentReceipt.staff_tax_code == tax_code),
    )


@dataclass(frozen=True)
class KeptRoles:
    # Role codes as the edit wizard names them.
    roles: list[str]
    # Receipts: one collaborating role at least must stay.
    staff: bool


# What the edit wizard locks; the end_* guards have the last word.
async def kept_roles(db: AsyncSession, tax_code: str) -> KeptRoles:
    roles = [
        role
        for role, held in (
            ("DOCENTE", await _taught(db, tax_code)),
            ("STUDENTE", await _learnt(db, tax_code)),
        )
        if held
    ]

    return KeptRoles(roles, await _paid_staff(db, tax_code))


# Begun availabilities and confirmed hours stay; those ahead go once agreed.
async def end_teaching(db: AsyncSession, tax_code: str, losses: Losses) -> None:
    if await _taught(db, tax_code):
        raise _refused("Docente")

    ahead = await count_hours_ahead(db, tax_code, learning=False)

    if ahead:
        losses.note(_TEACHING_AHEAD + (_TEACHING_LESSONS if ahead.lessons else ""))

    await drop_hours_ahead(db, tax_code, learning=False)


# Begun presences, confirmed hours and payments stay; presences ahead go once agreed.
async def end_learning(db: AsyncSession, tax_code: str, losses: Losses) -> None:
    if await _learnt(db, tax_code):
        raise _refused("Studente")

    ahead = await count_hours_ahead(db, tax_code, teaching=False)

    if ahead:
        losses.note(
            _LEARNING_AHEAD.format(
                lessons=_LEARNING_LESSONS if ahead.lessons else "",
            ),
        )

    await drop_hours_ahead(db, tax_code, teaching=False)


# The last collaborating role: receipts paid to the person stay.
async def end_staff(db: AsyncSession, tax_code: str, role: str) -> None:
    if await _paid_staff(db, tax_code):
        raise _refused(role)
