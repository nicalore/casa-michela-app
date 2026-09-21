from html import escape
from typing import Final

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity
from app.core.labels import role_label
from app.models.person import Person
from app.schemas.support import ProblemReport
from app.services import email_service

# A word to whoever builds the app, from anyone signed in.
router = APIRouter(prefix="/support", tags=["support"])

_REPORT_SENT_MESSAGE: Final[str] = "Segnalazione inviata correttamente"
_REPORT_EMAIL_ERROR: Final[str] = "Impossibile inviare la mail tramite Resend: {error}"

_REPORT_EMAIL_SUBJECT: Final[str] = "Segnalazione problema - {full_name}"
_REPORT_EMAIL_HEADING: Final[str] = "Problema segnalato"

_REPORT_EMAIL_BODY: Final[str] = """
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
"""


# The reporter's address is the reply-to; the role is the hat worn when it went wrong.
@router.post("/report-problem")
async def report_problem(
    payload: ProblemReport,
    identity: CurrentIdentity,
    db: DbSession,
) -> dict[str, str]:
    person = await db.get_one(Person, identity.tax_code)
    full_name = f"{person.first_name} {person.last_name}"

    try:
        email_service.send_email(
            recipient=email_service.DEVELOPER_ADDRESS,
            reply_to=person.email,
            subject=_REPORT_EMAIL_SUBJECT.format(full_name=full_name),
            heading=_REPORT_EMAIL_HEADING,
            greeting=email_service.DEVELOPER_GREETING,
            body=_REPORT_EMAIL_BODY.format(
                full_name=escape(full_name),
                role=escape(role_label(identity.active_role or "")),
                description=escape(payload.description).replace("\n", "<br>"),
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
