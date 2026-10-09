import base64
import logging
import time
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from html import escape
from typing import Final
from zoneinfo import ZoneInfo

import resend
import resend.exceptions

from app.models.notice import Notice, NoticeFile
from app.services import email_service
from app.services.notice_markdown import email_html

logger = logging.getLogger("notices")

_ROME: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_MONTHS: Final[tuple[str, ...]] = (
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
)

_EDITED_SUBJECT: Final[str] = "Modifica comunicazione - {title}"

# Where the association signs its other emails, set apart in a tinted panel.
_SIGNATURE: Final[str] = (
    '<div style="margin: 40px 0 0 0; padding: 18px 22px; border-radius: 16px; '
    f"background-color: {email_service.PAPER}; "
    f'border: 1px solid {email_service.LINE};">'
    '<p style="margin: 0; font-size: 17px;">Comunicazione inviata da '
    f'<strong style="color: {email_service.INK};">{{author}}</strong></p>'
    "{edited}</div>"
)

_EDITED_NOTE: Final[str] = (
    f'<p style="margin: 6px 0 0 0; color: {email_service.MUTED}; font-size: 15px;">'
    "Questa comunicazione è stata modificata il {day} alle {time}.</p>"
)

# Above the message's own headings, the largest of which is 26 px.
_HEADING_SIZE: Final[int] = 30

# Resend takes two requests a second unless the plan says otherwise.
SPACING_SECONDS: float = 0.6

_ATTEMPTS: Final[int] = 3


@dataclass(frozen=True)
class NoticeMail:
    notice_id: int
    # The sending's instant: retries of one sending share their idempotency keys.
    stamp: str
    addresses: list[str]
    signature: str
    subject: str
    heading: str
    body: str
    attachments: list[resend.Attachment]


def image_content_id(key: str) -> str:
    return f"notice-image-{key}"


def _day_and_time(instant: datetime) -> tuple[str, str]:
    local = instant.astimezone(_ROME)

    return f"{local.day} {_MONTHS[local.month - 1]} {local.year}", f"{local:%H:%M}"


def _attachment(file: NoticeFile) -> resend.Attachment:
    attachment: resend.Attachment = {
        "content": base64.b64encode(file.content).decode(),
        "filename": file.file_name,
        "content_type": file.content_type,
    }

    if file.image_key is not None:
        attachment["content_id"] = image_content_id(file.image_key)

    return attachment


# Built inside the request: the delivery runs after the session has closed.
def compose(
    notice: Notice,
    files: Sequence[NoticeFile],
    addresses: list[str],
) -> NoticeMail:
    author = escape(f"{notice.author.first_name} {notice.author.last_name}")
    edited = ""
    subject = notice.title
    sent_at = notice.created_at

    if notice.edited_at is not None:
        day, hour = _day_and_time(notice.edited_at)
        edited = _EDITED_NOTE.format(day=day, time=hour)
        subject = _EDITED_SUBJECT.format(title=notice.title)
        sent_at = notice.edited_at

    return NoticeMail(
        notice_id=notice.id,
        stamp=f"{sent_at.timestamp():.0f}",
        addresses=addresses,
        signature=_SIGNATURE.format(author=author, edited=edited),
        subject=subject,
        heading=escape(notice.title),
        body=email_html(notice.message, image_content_id),
        attachments=[_attachment(file) for file in files],
    )


def _send_one(mail: NoticeMail, index: int, address: str) -> None:
    for attempt in range(_ATTEMPTS):
        try:
            email_service.send_email(
                address,
                mail.subject,
                mail.heading,
                mail.body,
                reply_to=None,
                greeting="",
                attachments=mail.attachments,
                idempotency_key=f"notice-{mail.notice_id}-{mail.stamp}-{index}",
                signature=mail.signature,
                heading_size=_HEADING_SIZE,
            )

            return
        except resend.exceptions.RateLimitError:
            time.sleep(1 + attempt)
        except Exception:
            logger.exception("Notice %s not delivered to one address", mail.notice_id)

            return

    logger.error("Notice %s refused by the rate limit", mail.notice_id)


# One email per address, never a shared To or Bcc: nobody sees the others.
def deliver(mail: NoticeMail) -> None:
    for index, address in enumerate(mail.addresses):
        if index > 0:
            time.sleep(SPACING_SECONDS)

        _send_one(mail, index, address)
