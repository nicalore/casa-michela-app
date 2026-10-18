import logging
from collections.abc import Sequence
from dataclasses import dataclass
from html import escape
from typing import Final

from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator import Administrator, AdministratorRoleEnum
from app.models.notification import Notification, NotificationKindEnum
from app.models.person import Person
from app.models.report import Report, ReportKindEnum, ReportRead
from app.repositories.identity_repository import IdentityRepository
from app.services import email_service
from app.services.notice_mail import day_and_time
from app.services.notifications import dismissals, notify, reachable_identities
from app.services.push import PushBatch
from app.services.report_readers import audience, reader_role

logger = logging.getLogger("reports")

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.REPORT_RECEIVED

_TITLE: Final[str] = "Nuova segnalazione da {full_name}"
_BODY: Final[str] = "Tocca per leggerla"
_WEB_BODY: Final[str] = "Clicca per leggerla"

_GREETING: Final[str] = "Ciao {first_name},"

_RESOLVED_SUBJECT: Final[str] = "Segnalazione risolta"
_RESOLVED_BODY: Final[str] = """
    <p>La segnalazione che hai inviato il giorno {day} è stata risolta. Grazie!</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px;">
        {fields}
    </div>
"""
_FIELD: Final[str] = """
        <p style="margin: 0 0 4px 0; color: {muted}; font-size: 11px; font-weight: 600;
                  letter-spacing: 1.4px; text-transform: uppercase;">{label}</p>
        <p style="margin: 0;">{value}</p>
"""
_FIELD_GAP: Final[str] = '<div style="height: 16px;"></div>'


class ReportNotSentError(Exception):
    pass


async def _holders(
    db: AsyncSession,
    roles: frozenset[AdministratorRoleEnum],
) -> list[Person]:
    tax_codes = await db.scalars(
        select(Administrator.tax_code)
        .where(Administrator.role.in_(roles))
        .order_by(Administrator.tax_code)
    )
    repository = IdentityRepository(db)
    people = [await repository.get_person_identity(code) for code in tax_codes]

    return [
        person
        for person in people
        if person is not None and reader_role(person) in roles
    ]


# One email per reader but its author; with no reader at all, the association's
# mailbox. Fails only if every one does.
async def send_to_readers(
    db: AsyncSession,
    report: Report,
    *,
    subject: str,
    heading: str,
    body: str,
    reply_to: str | None = email_service.CONTACT_ADDRESS,
) -> None:
    holders = await _holders(db, audience(report))
    recipients = [
        (person.email, _GREETING.format(first_name=escape(person.first_name)))
        for person in holders
        if person.tax_code != report.reporter_tax_code
    ]

    if not holders:
        recipients = [(email_service.CONTACT_ADDRESS, email_service.GREETING)]

    # Its author is its only reader: they have it in the app already.
    if not recipients:
        return

    failure: Exception | None = None
    sent = False

    for address, greeting in recipients:
        try:
            email_service.send_email(
                recipient=address,
                subject=subject,
                heading=heading,
                body=body,
                reply_to=reply_to,
                greeting=greeting,
            )
            sent = True
        except Exception as err:
            logger.exception("Report not delivered to one reader")
            failure = err

    if not sent:
        raise ReportNotSentError(str(failure)) from failure


# Kept and told to its readers in the app, but its author, who has read it.
async def record_report(
    db: AsyncSession,
    reporter: Person,
    reporter_role: str | None,
    kind: ReportKindEnum,
    *,
    person_tax_code: str | None = None,
    title: str | None = None,
    description: str | None = None,
    corrections: Sequence[tuple[str, str]] | None = None,
) -> tuple[Report, PushBatch]:
    report = Report(
        kind=kind,
        reporter_tax_code=reporter.tax_code,
        reporter_role=reporter_role,
        person_tax_code=person_tax_code,
        title=title,
        description=description,
        corrections=(
            None
            if corrections is None
            else [{"field": field, "value": value} for field, value in corrections]
        ),
    )
    db.add(report)
    await db.flush()

    roles = audience(report)
    readers = [
        account.tax_code
        for account in await reachable_identities(db)
        if reader_role(account.person) in roles
    ]

    if reporter.tax_code in readers:
        db.add(ReportRead(report_id=report.id, account_tax_code=reporter.tax_code))

    batch = await notify(
        db,
        [code for code in readers if code != reporter.tax_code],
        kind=_KIND,
        title=_TITLE.format(full_name=f"{reporter.first_name} {reporter.last_name}"),
        body=_BODY,
        web_body=_WEB_BODY,
        report_id=report.id,
    )

    return report, batch


# Opened by one reader: read for them only; its news stays until it is resolved.
async def report_opened(db: AsyncSession, report_id: int, tax_code: str) -> None:
    await db.execute(
        insert(ReportRead)
        .values(report_id=report_id, account_tax_code=tax_code)
        .on_conflict_do_nothing(index_elements=["report_id", "account_tax_code"])
    )


# Resolved for everyone: off every list, and every reader's news of it goes.
async def resolve_report(db: AsyncSession, report: Report, tax_code: str) -> PushBatch:
    report.resolved_at = func.now()
    report.resolved_by_tax_code = tax_code

    rows = await db.scalars(
        update(Notification)
        .where(
            Notification.kind == _KIND,
            Notification.report_id == report.id,
            Notification.withdrawn_at.is_(None),
        )
        .values(withdrawn_at=func.now())
        .returning(Notification)
    )

    # Read ones too: the push is what makes every device drop it from its card.
    return await dismissals(db, list(rows))


@dataclass(frozen=True)
class ResolvedMail:
    report_id: int
    address: str
    greeting: str
    body: str


def _fields(report: Report) -> list[tuple[str, str]]:
    if report.kind == ReportKindEnum.PERSONAL_DATA:
        return [
            (correction["field"], correction["value"])
            for correction in report.corrections or []
        ]

    if report.kind == ReportKindEnum.MISSING_SUBJECT:
        return [
            ("Disciplina", report.title or ""),
            ("Descrizione", report.description or ""),
        ]

    return [("Descrizione", report.description or "")]


# The reporter's thanks, with what they sent below.
def resolved_mail(report: Report, reporter: Person) -> ResolvedMail:
    day, _ = day_and_time(report.created_at)
    fields = [(label, value) for label, value in _fields(report) if value]

    return ResolvedMail(
        report_id=report.id,
        address=reporter.email,
        greeting=_GREETING.format(first_name=escape(reporter.first_name)),
        body=_RESOLVED_BODY.format(
            day=day,
            fields=_FIELD_GAP.join(
                _FIELD.format(
                    label=escape(label),
                    value=escape(value).replace("\n", "<br>"),
                    muted=email_service.MUTED,
                )
                for label, value in fields
            ),
            paper=email_service.PAPER,
            line=email_service.LINE,
        ),
    )


# In the background: the resolution stands whether the email goes or not.
def deliver_resolved(mail: ResolvedMail) -> None:
    try:
        email_service.send_email(
            recipient=mail.address,
            subject=_RESOLVED_SUBJECT,
            heading=_RESOLVED_SUBJECT,
            body=mail.body,
            greeting=mail.greeting,
            idempotency_key=f"report-{mail.report_id}-resolved",
        )
    except Exception:
        logger.exception("Report %s resolved but its author not told", mail.report_id)
