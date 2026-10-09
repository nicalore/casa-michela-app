from datetime import date, datetime
from typing import Final

from pydantic import BaseModel, field_validator

from app.core.booking_window import today_in_rome
from app.models.notice import NoticeRoleEnum

_PAST_DAY_ERROR: Final[str] = "La data deve essere oggi o un giorno successivo."


class NoticeAttachmentResponse(BaseModel):
    id: int
    file_name: str
    content_type: str
    size: int


class NoticeImageResponse(BaseModel):
    key: str
    content_type: str
    size: int


class NoticeSummaryResponse(BaseModel):
    id: int
    title: str
    preview: str
    author_tax_code: str
    author_name: str
    recipients: list[NoticeRoleEnum]
    attachment_count: int
    created_at: datetime
    edited_at: datetime | None
    # Both None unless pinned today.
    pinned_at: datetime | None
    pinned_until: date | None


class NoticeResponse(NoticeSummaryResponse):
    message: str
    recipient_count: int
    attachments: list[NoticeAttachmentResponse]
    images: list[NoticeImageResponse]
    # The optimistic concurrency token an edit echoes back.
    updated_at: datetime


# A line of the home card.
class NoticeHeadlineResponse(BaseModel):
    id: int
    title: str
    author_name: str
    created_at: datetime
    pinned: bool


# A card of the list a role reads: no recipients, no tax codes, no pin's last day.
class NoticeReceivedResponse(BaseModel):
    id: int
    title: str
    preview: str
    author_name: str
    attachment_count: int
    created_at: datetime
    edited_at: datetime | None
    # None unless pinned today.
    pinned_at: datetime | None


# What a reader who is not an administrator is shown: no recipients, no tax codes.
class NoticeReadingResponse(BaseModel):
    id: int
    title: str
    author_name: str
    created_at: datetime
    edited_at: datetime | None
    message: str
    attachments: list[NoticeAttachmentResponse]
    images: list[NoticeImageResponse]


class NoticeRecipientsResponse(BaseModel):
    people: int
    # Fewer than people when several share one address.
    emails: int


class NoticePinWrite(BaseModel):
    # None pins it until someone unpins it.
    until: date | None = None

    @field_validator("until")
    @classmethod
    def _not_past(cls, until: date | None) -> date | None:
        if until is not None and until < today_in_rome():
            raise ValueError(_PAST_DAY_ERROR)

        return until
