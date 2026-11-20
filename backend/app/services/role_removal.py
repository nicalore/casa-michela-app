from dataclasses import dataclass
from typing import Any, Final

from fastapi import HTTPException, status
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.i18n import tr
from app.models.confirmed_hours import ConfirmedHours
from app.models.payment_receipt import PaymentReceipt
from app.models.student_hours import StudentConfirmedHours
from app.models.student_payment import StudentPayment
from app.services.bilingual import Bilingual
from app.services.collaboration import (
    count_hours_ahead,
    drop_hours_ahead,
    has_begun_hours,
)
from app.services.write_losses import Losses

# A role is taken away only to fix a mistake: once it has a history it stays,
# and the person stops through the collaboration, a lapse or a revocation.
_HISTORY_ERROR: Final[Bilingual] = Bilingual(
    "Impossibile togliere il ruolo {role}: ci sono lezioni, ore o pagamenti "
    "registrati.",
    "The role {role} cannot be removed: there are lessons, hours or payments recorded.",
)

_TEACHING_AHEAD: Final[Bilingual] = Bilingual(
    "Togliendo il ruolo Docente, le sue disponibilità non ancora iniziate verranno "
    "eliminate definitivamente.",
    "Removing the Teacher role permanently deletes their availability that has not "
    "started yet.",
)
_TEACHING_LESSONS: Final[Bilingual] = Bilingual(
    " Le lezioni già pianificate verranno tolte dal calendario e dovranno essere "
    "nuovamente pianificate.",
    " The lessons already planned will be taken off the calendar and will have to be "
    "planned again.",
)
_LEARNING_AHEAD: Final[Bilingual] = Bilingual(
    "Togliendo il ruolo Studente, le sue presenze non ancora iniziate verranno "
    "eliminate definitivamente, insieme alle prenotazioni{lessons}.",
    "Removing the Student role permanently deletes their attendance that has not "
    "started yet, together with the bookings{lessons}.",
)
_LEARNING_LESSONS: Final[Bilingual] = Bilingual(
    " e alle lezioni già pianificate",
    " and the lessons already planned",
)


# Roles arrive by their Italian names; an English reader gets the glossary's.
_ENGLISH_ROLES: Final[dict[str, str]] = {
    "Docente": "Teacher",
    "Studente": "Student",
    "Amministratore": "Administrator",
    "Psicologo": "Psychologist",
}


def _refused(role: str) -> HTTPException:
    role = tr(role, _ENGLISH_ROLES.get(role, role))

    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=_HISTORY_ERROR.for_request().format(role=role),
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
        lessons = _TEACHING_LESSONS.for_request() if ahead.lessons else ""
        losses.note(_TEACHING_AHEAD.for_request() + lessons)

    await drop_hours_ahead(db, tax_code, learning=False)


# Begun presences, confirmed hours and payments stay; presences ahead go once agreed.
async def end_learning(db: AsyncSession, tax_code: str, losses: Losses) -> None:
    if await _learnt(db, tax_code):
        raise _refused("Studente")

    ahead = await count_hours_ahead(db, tax_code, teaching=False)

    if ahead:
        losses.note(
            _LEARNING_AHEAD.for_request().format(
                lessons=_LEARNING_LESSONS.for_request() if ahead.lessons else "",
            ),
        )

    await drop_hours_ahead(db, tax_code, teaching=False)


# The last collaborating role: receipts paid to the person stay.
async def end_staff(db: AsyncSession, tax_code: str, role: str) -> None:
    if await _paid_staff(db, tax_code):
        raise _refused(role)
