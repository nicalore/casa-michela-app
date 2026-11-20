from html import escape
from typing import Final

from fastapi import APIRouter, BackgroundTasks, HTTPException, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity
from app.core.i18n import ENGLISH, ITALIAN, tr
from app.core.labels import role_label
from app.models.person import GenderEnum, Person
from app.models.report import ReportKindEnum
from app.schemas.support import ProblemReport
from app.services import email_service, push
from app.services.bilingual import Bilingual
from app.services.reports import (
    ReportNotSentError,
    deliver_rest,
    record_report,
    send_to_readers,
)

# A word to the IT managers, from anyone signed in.
router = APIRouter(prefix="/support", tags=["support"])

_REPORT_SENT_MESSAGE: Final[tuple[str, str]] = (
    "Segnalazione inviata correttamente",
    "Report sent successfully",
)
_REPORT_EMAIL_ERROR: Final[tuple[str, str]] = (
    "Impossibile inviare la mail tramite Resend: {error}",
    "Couldn't send the email through Resend: {error}",
)

_REPORT_EMAIL_SUBJECT: Final[Bilingual] = Bilingual(
    "Segnalazione problema - {full_name}",
    "Problem report - {full_name}",
)
_REPORT_EMAIL_HEADING: Final[Bilingual] = Bilingual(
    "Problema segnalato",
    "Problem reported",
)

_REPORT_EMAIL_BODY: Final[Bilingual] = Bilingual(
    """
    <p><strong>{full_name}</strong> ha segnalato un problema nell'app.</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px;">
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Ruolo</p>
        <p style="margin: 0 0 16px 0;"><strong style="color: {ink}; font-size: 17px;">{role}</strong></p>
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Descrizione</p>
        <p style="margin: 0;">{description}</p>
    </div>
    <p>Puoi rispondere direttamente a questa email: la risposta arriverà a <a href="mailto:{email}" style="color: {teal};">{email}</a>.</p>
""",
    """
    <p><strong>{full_name}</strong> reported a problem in the app.</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px;">
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Role</p>
        <p style="margin: 0 0 16px 0;"><strong style="color: {ink}; font-size: 17px;">{role}</strong></p>
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">Description</p>
        <p style="margin: 0;">{description}</p>
    </div>
    <p>You can reply directly to this email: the reply will go to <a href="mailto:{email}" style="color: {teal};">{email}</a>.</p>
""",
)


# The reporter's address is the reply-to; the role is the hat worn when it went wrong.
@router.post("/report-problem")
async def report_problem(
    payload: ProblemReport,
    identity: CurrentIdentity,
    db: DbSession,
    background: BackgroundTasks,
) -> dict[str, str]:
    person = await db.get_one(Person, identity.tax_code)
    full_name = f"{person.first_name} {person.last_name}"
    feminine = person.gender == GenderEnum.F
    report, batch = await record_report(
        db,
        person,
        identity.active_role,
        ReportKindEnum.APP_PROBLEM,
        description=payload.description,
    )

    try:
        rest = await send_to_readers(
            db,
            report,
            reply_to=person.email,
            subject=_REPORT_EMAIL_SUBJECT.format(full_name=full_name),
            heading=_REPORT_EMAIL_HEADING,
            # The role is worded in each reader's language, the rest as written.
            body=Bilingual(
                *(
                    template.format(
                        full_name=escape(full_name),
                        role=escape(
                            role_label(
                                identity.active_role or "",
                                feminine=feminine,
                                language=language,
                            )
                        ),
                        description=escape(payload.description).replace(
                            "\n", "<br>"
                        ),
                        email=escape(person.email),
                        paper=email_service.PAPER,
                        line=email_service.LINE,
                        ink=email_service.INK,
                        muted=email_service.MUTED,
                        teal=email_service.TEAL,
                    )
                    for template, language in (
                        (_REPORT_EMAIL_BODY.it, ITALIAN),
                        (_REPORT_EMAIL_BODY.en, ENGLISH),
                    )
                )
            ),
        )
    except ReportNotSentError as err:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=tr(*_REPORT_EMAIL_ERROR).format(error=err),
        ) from err

    await db.commit()
    background.add_task(push.deliver, batch)
    background.add_task(deliver_rest, rest)

    return {"message": tr(*_REPORT_SENT_MESSAGE)}
