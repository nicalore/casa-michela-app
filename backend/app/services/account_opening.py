import re
import unicodedata
from dataclasses import dataclass
from html import escape
from typing import Final

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.i18n import tr_for
from app.core.password_policy import generate_temporary_password
from app.core.security import hash_password_async
from app.models.account import Account, AccountStatusEnum
from app.models.membership import MembershipRevocationEnum
from app.models.person import GenderEnum, Person
from app.services import email_service
from app.services.bilingual import Bilingual

# Room for a ".NN" suffix within Account.username's 50 characters.
_USERNAME_STEM_LENGTH: Final[int] = 47

_WELCOME_SUBJECT: Final[Bilingual] = Bilingual(
    "{welcome} in Associazione Casa Michela",
    "Welcome to Associazione Casa Michela",
)
_WELCOME_HEADING: Final[Bilingual] = Bilingual(
    "{welcome} in Associazione Casa Michela!",
    "Welcome to Associazione Casa Michela!",
)
_WELCOME_GREETING: Final[Bilingual] = Bilingual("Ciao {first_name},", "Hi {first_name},")

_WELCOME_BODY: Final[str] = """
    <p>{intro}</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px;">
        <p style="margin: 0 0 8px 0;">{username_label}: <strong style="color: {ink};">{username}</strong></p>
        <p style="margin: 0;">{password_label}: <strong style="color: {ink}; font-family: Menlo, Consolas, monospace; letter-spacing: 0.5px;">{password}</strong></p>
        <p style="margin: 8px 0 0 0; color: {muted}; font-size: 14px;">{change_note}</p>
    </div>
    <p>{computer_note} <a href="{app_url}" style="color: {teal};">{app_url}</a></p>
    {stores}
"""
_WELCOME_INTRO: Final[Bilingual] = Bilingual(
    "Di seguito trovi le credenziali per accedere all'applicazione, che sarà il "
    "tuo strumento principale per partecipare alle attività dell'Associazione.",
    "Below are your credentials to sign in to the app, which will be your main "
    "tool for taking part in the Association's activities.",
)
_USERNAME_LABEL: Final[Bilingual] = Bilingual("Nome utente", "Username")
_PASSWORD_LABEL: Final[Bilingual] = Bilingual(
    "Password temporanea",
    "Temporary password",
)
_CHANGE_NOTE: Final[Bilingual] = Bilingual(
    "Ti verrà chiesto di cambiarla al primo accesso.",
    "You will be asked to change it the first time you sign in.",
)
_COMPUTER_NOTE: Final[Bilingual] = Bilingual(
    "Puoi accedere da computer al link",
    "On a computer you can sign in at",
)

_STORES_PARAGRAPH: Final[Bilingual] = Bilingual(
    "<p>Puoi anche scaricare l'applicazione ufficiale per smartphone e tablet: "
    "{links}.</p>",
    "<p>You can also download the official app for smartphones and tablets: "
    "{links}.</p>",
)
_STORE_LINK: Final[str] = '<a href="{url}" style="color: {teal};">{name}</a>'


@dataclass(frozen=True)
class OpenedAccount:
    person: Person
    username: str
    # Shown once, in the welcome email; only its hash is stored.
    password: str


# Judged on the latest membership, like everywhere else in the register.
def membership_revoked(person: Person) -> bool:
    member = person.member_profile

    if member is None or not member.memberships:
        return False

    latest = max(member.memberships, key=lambda membership: membership.year)

    return latest.revocation != MembershipRevocationEnum.NO


# Accents and anything but letters and digits dropped: "D'Àngelo" -> "dangelo".
def _username_part(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()

    return re.sub(r"[^a-z0-9]", "", plain.lower())


def username_stem(person: Person) -> str:
    parts = [_username_part(person.first_name), _username_part(person.last_name)]
    stem = ".".join(part for part in parts if part) or person.tax_code.lower()

    return stem[:_USERNAME_STEM_LENGTH].rstrip(".")


# name.surname, then name.surname.1, .2 and so on for namesakes.
async def free_username(session: AsyncSession, person: Person) -> str:
    stem = username_stem(person)

    taken = set(
        await session.scalars(
            select(Account.username).where(
                or_(Account.username == stem, Account.username.like(f"{stem}.%"))
            )
        )
    )

    if stem not in taken:
        return stem

    number = 1

    while f"{stem}.{number}" in taken:
        number += 1

    return f"{stem}.{number}"


# Flushed, so the next username in the same request sees this one taken.
async def open_account(
    session: AsyncSession,
    person: Person,
    *,
    autonomous_bookings: bool = False,
) -> OpenedAccount:
    username = await free_username(session, person)
    password = generate_temporary_password()

    session.add(
        Account(
            tax_code=person.tax_code,
            username=username,
            status=AccountStatusEnum.ACTIVE,
            password_hash=await hash_password_async(password),
            password_reset_required=True,
            autonomous_bookings=autonomous_bookings,
        )
    )
    await session.flush()

    return OpenedAccount(person=person, username=username, password=password)


def _store_links(language: str | None) -> str:
    stores = [
        (url, name)
        for url, name in (
            (settings.app_store_url, "App Store"),
            (settings.play_store_url, "Google Play"),
        )
        if url
    ]

    if not stores:
        return ""

    links = tr_for(language, " e ", " and ").join(
        _STORE_LINK.format(url=escape(url), name=name, teal=email_service.TEAL)
        for url, name in stores
    )

    return _STORES_PARAGRAPH.to(language).format(links=links)


# Raises whatever Resend raises: without this email the password is lost. A new
# account has chosen no language yet, so it reads Italian unless told otherwise.
def send_welcome_email(opened: OpenedAccount, language: str | None = None) -> None:
    person = opened.person
    welcome = "Benvenuta" if person.gender == GenderEnum.F else "Benvenuto"

    email_service.send_email(
        recipient=person.email,
        subject=_WELCOME_SUBJECT.to(language).format(welcome=welcome),
        heading=_WELCOME_HEADING.to(language).format(welcome=welcome),
        greeting=_WELCOME_GREETING.to(language).format(
            first_name=escape(person.first_name),
        ),
        language=language,
        body=_WELCOME_BODY.format(
            intro=_WELCOME_INTRO.to(language),
            username_label=_USERNAME_LABEL.to(language),
            password_label=_PASSWORD_LABEL.to(language),
            change_note=_CHANGE_NOTE.to(language),
            computer_note=_COMPUTER_NOTE.to(language),
            username=escape(opened.username),
            password=escape(opened.password),
            app_url=escape(settings.frontend_url),
            stores=_store_links(language),
            paper=email_service.PAPER,
            line=email_service.LINE,
            ink=email_service.INK,
            muted=email_service.MUTED,
            teal=email_service.TEAL,
        ),
    )
