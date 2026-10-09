import mimetypes
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Final

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload, undefer

from app.api.rbac import IdentityContext
from app.core import field_lengths
from app.core.booking_window import today_in_rome
from app.models.notice import Notice, NoticeFile, NoticePin, NoticeRoleEnum
from app.schemas.notice import (
    NoticeAttachmentResponse,
    NoticeHeadlineResponse,
    NoticeImageResponse,
    NoticeReadingResponse,
    NoticeReceivedResponse,
    NoticeResponse,
    NoticeSummaryResponse,
)
from app.services.notice_markdown import image_keys, preview

# Mirrored by frontend/lib/features/association/notices/notice_limits.dart.
MAX_FILES_BYTES: Final[int] = 15 * 1024 * 1024

# Lines on the home card, pinned ones included.
HOME_LIMIT: Final[int] = 5

_NOTICE_NOT_FOUND_ERROR: Final[str] = "Comunicazione non trovata"
_FILE_NOT_FOUND_ERROR: Final[str] = "File non trovato"
_NOT_THE_AUTHOR_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"
_TOO_LARGE_ERROR: Final[str] = "Gli allegati superano i 15 MB totali."
_NOT_AN_IMAGE_ERROR: Final[str] = "Nel messaggio si possono inserire solo immagini."
_MISSING_IMAGE_ERROR: Final[str] = "Un'immagine del messaggio non è stata caricata."

_DEFAULT_CONTENT_TYPE: Final[str] = "application/octet-stream"
_DEFAULT_FILE_NAME: Final[str] = "allegato"


@dataclass(frozen=True)
class Upload:
    file_name: str
    content_type: str
    content: bytes


def _file_name(name: str | None) -> str:
    cleaned = (name or "").strip() or _DEFAULT_FILE_NAME

    if len(cleaned) <= field_lengths.FILE_NAME:
        return cleaned

    # Keeps the extension, which tells a mail client how to open the file.
    stem, dot, extension = cleaned.rpartition(".")

    if not dot or len(extension) > 10:
        return cleaned[: field_lengths.FILE_NAME]

    return stem[: field_lengths.FILE_NAME - len(extension) - 1] + "." + extension


# Browsers send octet-stream for what they do not know; the name may tell more.
def _content_type(name: str, declared: str | None) -> str:
    if declared and declared != _DEFAULT_CONTENT_TYPE:
        return declared

    guessed, _ = mimetypes.guess_type(name)

    return guessed or _DEFAULT_CONTENT_TYPE


async def read_uploads(files: Sequence[UploadFile] | None) -> list[Upload]:
    uploads: list[Upload] = []
    total = 0

    for file in files or ():
        # Refused before reading when the client declared the size.
        if file.size is not None and total + file.size > MAX_FILES_BYTES:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=_TOO_LARGE_ERROR,
            )

        content = await file.read()
        total += len(content)
        name = _file_name(file.filename)
        uploads.append(
            Upload(
                file_name=name,
                content_type=_content_type(name, file.content_type),
                content=content,
            )
        )

    return uploads


def _stored(upload: Upload, image_key: str | None = None) -> NoticeFile:
    return NoticeFile(
        file_name=upload.file_name,
        content_type=upload.content_type,
        size=len(upload.content),
        image_key=image_key,
        content=upload.content,
    )


# The message's images, kept or new; new uploads it does not show are dropped.
def settle_images(
    message: str,
    kept: Sequence[NoticeFile],
    uploads: Sequence[Upload],
) -> tuple[list[NoticeFile], list[NoticeFile]]:
    shown = image_keys(message)
    existing = {file.image_key: file for file in kept}
    # A new image travels with its key as the file name.
    new = {upload.file_name: upload for upload in uploads}

    keep: list[NoticeFile] = []
    add: list[NoticeFile] = []

    for key in shown:
        if key in existing:
            keep.append(existing[key])
            continue

        upload = new.get(key)

        if upload is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_MISSING_IMAGE_ERROR,
            )

        if not upload.content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_NOT_AN_IMAGE_ERROR,
            )

        add.append(_stored(upload, image_key=key))

    return keep, add


def attachments_of(uploads: Sequence[Upload]) -> list[NoticeFile]:
    return [_stored(upload) for upload in uploads]


def check_total_size(files: Sequence[NoticeFile]) -> None:
    if sum(file.size for file in files) > MAX_FILES_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=_TOO_LARGE_ERROR,
        )


async def load_notice(
    db: AsyncSession,
    notice_id: int,
    *,
    with_content: bool = False,
) -> Notice:
    files = selectinload(Notice.files)

    if with_content:
        files = files.options(undefer(NoticeFile.content))

    notice = await db.scalar(
        select(Notice)
        .options(joinedload(Notice.author), joinedload(Notice.pin), files)
        .where(Notice.id == notice_id)
        .execution_options(populate_existing=True)
    )

    if notice is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOTICE_NOT_FOUND_ERROR,
        )

    return notice


async def own_notice(
    db: AsyncSession,
    notice_id: int,
    *,
    author_tax_code: str,
    with_content: bool = True,
) -> Notice:
    notice = await load_notice(db, notice_id, with_content=with_content)

    if notice.author_tax_code != author_tax_code:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_NOT_THE_AUTHOR_ERROR,
        )

    return notice


async def notice_file(
    db: AsyncSession,
    notice_id: int,
    *,
    file_id: int | None = None,
    image_key: str | None = None,
) -> NoticeFile:
    query = (
        select(NoticeFile)
        .options(undefer(NoticeFile.content))
        .where(NoticeFile.notice_id == notice_id)
    )

    if file_id is not None:
        query = query.where(NoticeFile.id == file_id, NoticeFile.image_key.is_(None))
    else:
        query = query.where(NoticeFile.image_key == image_key)

    file = await db.scalar(query)

    if file is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_FILE_NOT_FOUND_ERROR,
        )

    return file


def _author_name(notice: Notice) -> str:
    return f"{notice.author.first_name} {notice.author.last_name}"


def active_pin(notice: Notice) -> NoticePin | None:
    pin = notice.pin

    if pin is None or (pin.until is not None and pin.until < today_in_rome()):
        return None

    return pin


# Pinned first, the latest pinned on top; then the newest sent.
def listing_order(notices: Sequence[Notice]) -> list[Notice]:
    pinned = [notice for notice in notices if active_pin(notice) is not None]
    others = [notice for notice in notices if active_pin(notice) is None]

    pinned.sort(key=lambda notice: notice.pin.pinned_at, reverse=True)
    others.sort(key=lambda notice: (notice.created_at, notice.id), reverse=True)

    return [*pinned, *others]


def summary_response(notice: Notice) -> NoticeSummaryResponse:
    pin = active_pin(notice)

    return NoticeSummaryResponse(
        id=notice.id,
        title=notice.title,
        preview=preview(notice.message),
        author_tax_code=notice.author_tax_code,
        author_name=_author_name(notice),
        recipients=notice.recipients,
        attachment_count=sum(1 for file in notice.files if file.image_key is None),
        created_at=notice.created_at,
        edited_at=notice.edited_at,
        pinned_at=None if pin is None else pin.pinned_at,
        pinned_until=None if pin is None else pin.until,
    )


def _attachments(notice: Notice) -> list[NoticeAttachmentResponse]:
    return [
        NoticeAttachmentResponse(
            id=file.id,
            file_name=file.file_name,
            content_type=file.content_type,
            size=file.size,
        )
        for file in notice.files
        if file.image_key is None
    ]


def _images(notice: Notice) -> list[NoticeImageResponse]:
    return [
        NoticeImageResponse(
            key=file.image_key,
            content_type=file.content_type,
            size=file.size,
        )
        for file in notice.files
        if file.image_key is not None
    ]


def received_response(notice: Notice) -> NoticeReceivedResponse:
    pin = active_pin(notice)

    return NoticeReceivedResponse(
        id=notice.id,
        title=notice.title,
        preview=preview(notice.message),
        author_name=_author_name(notice),
        attachment_count=sum(1 for file in notice.files if file.image_key is None),
        created_at=notice.created_at,
        edited_at=notice.edited_at,
        pinned_at=None if pin is None else pin.pinned_at,
    )


def notice_response(notice: Notice) -> NoticeResponse:
    return NoticeResponse(
        **summary_response(notice).model_dump(),
        message=notice.message,
        recipient_count=notice.recipient_count,
        attachments=_attachments(notice),
        images=_images(notice),
        updated_at=notice.updated_at,
    )


def reading_response(notice: Notice) -> NoticeReadingResponse:
    return NoticeReadingResponse(
        id=notice.id,
        title=notice.title,
        author_name=_author_name(notice),
        created_at=notice.created_at,
        edited_at=notice.edited_at,
        message=notice.message,
        attachments=_attachments(notice),
        images=_images(notice),
    )


def headline_response(notice: Notice) -> NoticeHeadlineResponse:
    return NoticeHeadlineResponse(
        id=notice.id,
        title=notice.title,
        author_name=_author_name(notice),
        created_at=notice.created_at,
        pinned=active_pin(notice) is not None,
    )


# Administrators read every notice; anyone else only those sent to a role they hold.
async def readable_notice(
    db: AsyncSession,
    notice_id: int,
    identity: IdentityContext,
) -> Notice:
    notice = await load_notice(db, notice_id)
    held = {role for role in NoticeRoleEnum if role.value in identity.roles}

    if not identity.is_admin and held.isdisjoint(notice.recipients):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOTICE_NOT_FOUND_ERROR,
        )

    return notice
