from collections.abc import Sequence
from html import escape
from typing import Final

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DbSession
from app.api.queries import select_parents_left_without_children
from app.api.rbac import CurrentIdentity, get_current_identity, require_role
from app.models.association_subject import AssociationSubject
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.person import Person
from app.models.teaching_competence import TeachingCompetence
from app.schemas.association_subject import (
    AssociationSubjectCreate,
    AssociationSubjectResponse,
    AssociationSubjectUpdate,
    MissingSubjectReport,
)
from app.services import email_service

router = APIRouter(
    prefix="/association-subjects",
    tags=["association-subjects"],
    # Reading takes a login; writing an administrator, route by route.
    dependencies=[Depends(get_current_identity)],
)

_REPORTER_ROLES: Final[tuple[str, ...]] = ("STUDENT", "PARENT")

_REPORT_SENT_MESSAGE: Final[str] = "Segnalazione inviata correttamente"
_REPORT_EMAIL_ERROR: Final[str] = "Impossibile inviare la mail tramite Resend: {error}"

_REPORT_EMAIL_SUBJECT: Final[str] = "Segnalazione disciplina mancante - {full_name}"
_REPORT_EMAIL_HEADING: Final[str] = "Disciplina mancante"

_REPORT_EMAIL_BODY: Final[str] = """
    <p><strong>{full_name}</strong> ha richiesto di aggiungere una disciplina.</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px;">
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Disciplina</p>
        <p style="margin: 0 0 16px 0;"><strong style="color: {ink}; font-size: 17px;">{name}</strong></p>
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Descrizione</p>
        {description}
    </div>
    <p>Puoi rispondere direttamente a questa email: la risposta arriverà a <a href="mailto:{email}" style="color: {teal};">{email}</a>.</p>
"""

_REPORT_DESCRIPTION: Final[str] = '<p style="margin: 0;">{description}</p>'
_REPORT_NO_DESCRIPTION: Final[str] = (
    '<p style="margin: 0; color: {muted}; font-style: italic;">'
    "Nessuna descrizione fornita.</p>"
)

_SUBJECT_NOT_FOUND_ERROR: Final[str] = "Materia non trovata."
_DUPLICATE_SUBJECT_ERROR: Final[str] = 'Esiste già la disciplina "{name}"'
_UPDATE_ERROR: Final[str] = "Errore durante l'aggiornamento."
_ORPHAN_MINISTRY_SUBJECT_ERROR: Final[str] = (
    "Impossibile eliminare: una materia ministeriale rimarrebbe senza "
    "discipline interne collegate."
)
_ORPHAN_TEACHER_ERROR: Final[str] = (
    "Impossibile eliminare: un docente rimarrebbe senza competenze."
)
_DELETE_CONSTRAINT_ERROR: Final[str] = (
    "Impossibile eliminare la materia in quanto protetta da vincoli referenziali."
)
_DELETE_SUCCESS_DETAIL: Final[str] = "Materia eliminata"


async def _get_subject_or_404(db: AsyncSession, subject_id: int) -> AssociationSubject:
    result = await db.execute(
        select(AssociationSubject).where(AssociationSubject.id == subject_id)
    )
    subject = result.scalars().first()

    if subject is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SUBJECT_NOT_FOUND_ERROR,
        )

    return subject


async def _assert_name_available(db: AsyncSession, name: str) -> None:
    result = await db.execute(
        select(AssociationSubject).where(AssociationSubject.name.ilike(name))
    )

    if result.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DUPLICATE_SUBJECT_ERROR.format(name=name),
        )


def _report_description(description: str | None) -> str:
    if description is None:
        return _REPORT_NO_DESCRIPTION.format(muted=email_service.MUTED)

    return _REPORT_DESCRIPTION.format(
        description=escape(description).replace("\n", "<br>"),
    )


# The reporter's own address is the reply-to, so a plain reply reaches them.
@router.post(
    "/report-missing",
    dependencies=[Depends(require_role(*_REPORTER_ROLES))],
)
async def report_missing_subject(
    payload: MissingSubjectReport,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    person = await db.get_one(Person, identity.tax_code)
    full_name = f"{person.first_name} {person.last_name}"

    try:
        email_service.send_email(
            recipient=await email_service.president_address(db),
            reply_to=person.email,
            subject=_REPORT_EMAIL_SUBJECT.format(full_name=full_name),
            heading=_REPORT_EMAIL_HEADING,
            body=_REPORT_EMAIL_BODY.format(
                full_name=escape(full_name),
                name=escape(payload.name),
                description=_report_description(payload.description),
                email=escape(person.email),
                paper=email_service.PAPER,
                line=email_service.LINE,
                ink=email_service.INK,
                muted=email_service.MUTED,
                teal=email_service.TEAL,
            ),
        )
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_REPORT_EMAIL_ERROR.format(error=err),
        ) from err

    return {"message": _REPORT_SENT_MESSAGE}


@router.get("/", response_model=list[AssociationSubjectResponse])
async def get_subjects(db: DbSession) -> Sequence[AssociationSubject]:
    result = await db.execute(
        select(AssociationSubject).order_by(AssociationSubject.created_at.desc())
    )

    return result.scalars().all()


@router.post(
    "/",
    response_model=AssociationSubjectResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
async def create_subject(
    payload: AssociationSubjectCreate,
    db: DbSession,
) -> AssociationSubject:
    await _assert_name_available(db, payload.name)

    new_subject = AssociationSubject(**payload.model_dump())
    db.add(new_subject)
    await db.commit()

    return new_subject


@router.put(
    "/{subject_id}",
    response_model=AssociationSubjectResponse,
    dependencies=[Depends(require_role("ADMIN"))],
)
async def update_subject(
    subject_id: int,
    payload: AssociationSubjectUpdate,
    db: DbSession,
) -> AssociationSubject:
    subject = await _get_subject_or_404(db, subject_id)

    if subject.name.lower() != payload.name.lower():
        await _assert_name_available(db, payload.name)

    subject.name = payload.name
    subject.area = payload.area
    subject.description = payload.description

    try:
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UPDATE_ERROR,
        ) from err

    return subject


@router.delete(
    "/{subject_id}",
    dependencies=[Depends(require_role("ADMIN"))],
)
async def delete_subject(subject_id: int, db: DbSession) -> dict[str, str]:
    subject = await _get_subject_or_404(db, subject_id)

    orphan_ministry_subjects = await db.execute(
        select_parents_left_without_children(
            MinistryAssociationSubject.ministry_subject_id,
            MinistryAssociationSubject.association_subject_id,
            subject_id,
        )
    )

    if orphan_ministry_subjects.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_MINISTRY_SUBJECT_ERROR,
        )

    orphan_teachers = await db.execute(
        select_parents_left_without_children(
            TeachingCompetence.teacher_tax_code,
            TeachingCompetence.association_subject_id,
            subject_id,
            only=TeachingCompetence.valid_to.is_(None),
        )
    )

    if orphan_teachers.scalars().first() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ORPHAN_TEACHER_ERROR,
        )

    try:
        await db.delete(subject)
        await db.commit()
    except IntegrityError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_DELETE_CONSTRAINT_ERROR,
        ) from err

    return {"detail": _DELETE_SUCCESS_DETAIL}