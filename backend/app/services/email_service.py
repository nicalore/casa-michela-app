from typing import Final

import resend
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.person import Person

resend.api_key = settings.resend_api_key

SENDER: Final[str] = "Associazione Casa Michela <supporto@app.casamichela.it>"

# The association's mailbox: replies, and reports until a president with an email.
CONTACT_ADDRESS: Final[str] = "nicolo.calore@casamichela.it"

# Whoever builds the app: problems and corrections go here, not to the president.
DEVELOPER_ADDRESS: Final[str] = "nicolo.calore@casamichela.it"
DEVELOPER_GREETING: Final[str] = "Ciao Nicolò,"

GREETING: Final[str] = "Ciao,"

LOGO_URL: Final[str] = (
    "https://primary.jwwb.nl/public/y/k/w/temp-mfffkbfpkmjgalfrjfhx/"
    "logo-casamichela-1-high-bl0vca.png?enable-io=true&width=100"
)

# App theme colours hand-copied: an email cannot read the theme.
INK: Final[str] = "#123A5E"
TEAL: Final[str] = "#0B6478"
PAPER: Final[str] = "#F5FAF9"
LINE: Final[str] = "#DDE8E6"
MUTED: Final[str] = "#5B7280"
BODY: Final[str] = "#122438"

# Inline styles: email clients guarantee nothing more.
_TEMPLATE: Final[str] = """
<div style="margin: 0; padding: 32px 16px; background-color: {paper};
            font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;">
    <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;
                border-radius: 28px; border: 1px solid {line};
                padding: 40px 40px 32px 40px; color: {body}; line-height: 1.6;">
        <div style="text-align: center; margin-bottom: 28px;">
            <img src="{logo_url}" alt="Associazione Casa Michela" style="width: 96px; height: auto;" />
            <p style="margin: 14px 0 0 0; color: {muted}; font-size: 11px;
                      font-weight: 600; letter-spacing: 1.4px; text-transform: uppercase;">
                Associazione Casa Michela
            </p>
        </div>
        <h2 style="margin: 0 0 20px 0; color: {ink}; font-size: 24px; font-weight: 700;
                   line-height: 1.25;"> {heading} </h2>
        <p style="margin: 0 0 14px 0;">{greeting}</p>
        {body_html}
        <p style="margin: 28px 0 0 0; padding-top: 24px; border-top: 1px solid {line};
                  color: {muted}; font-size: 14px;">
            A presto,<br>
            <strong style="color: {ink};">Associazione Casa Michela</strong>
        </p>
    </div>
</div>
"""


# Whoever holds the register reads what the members send in.
async def president_address(db: AsyncSession) -> str:
    email = await db.scalar(
        select(Person.email)
        .join(Administrator, Administrator.tax_code == Person.tax_code)
        .where(Administrator.role == AdministratorRoleEnum.PRESIDENT)
        .where(Person.email.is_not(None))
    )

    return email or CONTACT_ADDRESS


# Raises whatever Resend raises: the caller decides whether a lost email matters.
def send_email(
    recipient: str,
    subject: str,
    heading: str,
    body: str,
    reply_to: str = CONTACT_ADDRESS,
    greeting: str = GREETING,
) -> None:
    resend.Emails.send(
        {
            "from": SENDER,
            "to": recipient,
            "reply_to": reply_to,
            "subject": subject,
            "html": _TEMPLATE.format(
                logo_url=LOGO_URL,
                heading=heading,
                greeting=greeting,
                body_html=body,
                paper=PAPER,
                line=LINE,
                ink=INK,
                muted=MUTED,
                body=BODY,
            ),
        }
    )
