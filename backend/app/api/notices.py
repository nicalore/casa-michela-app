from datetime import UTC, datetime
from typing import Annotated, Final

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import Select, select
from sqlalchemy.orm import joinedload, selectinload

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.core import field_lengths
from app.core.downloads import inline_disposition
from app.core.optimistic_concurrency import assert_not_stale
from app.models.notice import Notice, NoticePin, NoticeRoleEnum
from app.schemas.notice import (
    NoticeHeadlineResponse,
    NoticePinWrite,
    NoticeReadingResponse,
    NoticeReceivedResponse,
    NoticeRecipientsResponse,
    NoticeResponse,
    NoticeSummaryResponse,
)
from app.schemas.validators import CleanStr
from app.services import notice_mail
from app.services.notice_recipients import recipients_of, unique_addresses
from app.services.notices import (
    HOME_LIMIT,
    attachments_of,
    check_total_size,
    headline_response,
    listing_order,
    load_notice,
    notice_file,
    notice_response,
    own_notice,
    read_uploads,
    readable_notice,
    reading_response,
    received_response,
    settle_images,
    summary_response,
)

_NOTICE_LABEL: Final[str] = "la comunicazione"

# Written by administrators, each editing and deleting their own but pinning anyone's;
# read by everyone they were sent to.
router = APIRouter(prefix="/notices", tags=["notices"])

Administrator = Annotated[IdentityContext, Depends(require_role("ADMIN"))]

Title = Annotated[
    CleanStr,
    Form(min_length=1, max_length=field_lengths.NOTICE_TITLE),
]

Message = Annotated[
    CleanStr,
    Form(min_length=1, max_length=field_lengths.NOTICE_MESSAGE),
]

Recipients = Annotated[list[NoticeRoleEnum], Form(min_length=1)]

# Images of the message, each named by the key the message writes after image:.
Images = Annotated[list[UploadFile] | None, File()]

Attachments = Annotated[list[UploadFile] | None, File()]


def _deduplicated(roles: list[NoticeRoleEnum]) -> list[NoticeRoleEnum]:
    return [role for role in NoticeRoleEnum if role in roles]


@router.get("/", response_model=list[NoticeSummaryResponse])
async def list_notices(_: Administrator, db: DbSession) -> list[NoticeSummaryResponse]:
    notices = await db.scalars(
        select(Notice).options(
            joinedload(Notice.author),
            joinedload(Notice.pin),
            selectinload(Notice.files),
        )
    )

    return [summary_response(notice) for notice in listing_order(notices.all())]


@router.get("/recipients", response_model=NoticeRecipientsResponse)
async def count_recipients(
    _: Administrator,
    db: DbSession,
    recipients: Annotated[list[NoticeRoleEnum] | None, Query()] = None,
) -> NoticeRecipientsResponse:
    people = await recipients_of(db, recipients or ())

    return NoticeRecipientsResponse(
        people=len(people),
        emails=len(unique_addresses(people)),
    )


def _sent_to(role: NoticeRoleEnum, identity: IdentityContext) -> Select[tuple[Notice]]:
    require_role(role.value)(identity)

    return (
        select(Notice)
        .options(
            joinedload(Notice.author),
            joinedload(Notice.pin),
            selectinload(Notice.files),
        )
        .where(Notice.recipients.contains([role]))
    )


# The home of the role worn: pinned first, then the newest, all sent to that role.
@router.get("/home", response_model=list[NoticeHeadlineResponse])
async def home_notices(
    identity: CurrentIdentity,
    db: DbSession,
    role: Annotated[NoticeRoleEnum, Query()],
) -> list[NoticeHeadlineResponse]:
    notices = await db.scalars(_sent_to(role, identity))

    return [
        headline_response(notice)
        for notice in listing_order(notices.all())[:HOME_LIMIT]
    ]


# Everything sent to the role worn, for its own Associazione page.
@router.get("/received", response_model=list[NoticeReceivedResponse])
async def received_notices(
    identity: CurrentIdentity,
    db: DbSession,
    role: Annotated[NoticeRoleEnum, Query()],
) -> list[NoticeReceivedResponse]:
    notices = await db.scalars(_sent_to(role, identity))

    return [received_response(notice) for notice in listing_order(notices.all())]


@router.get("/{notice_id}", response_model=NoticeResponse | NoticeReadingResponse)
async def get_notice(
    notice_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> NoticeResponse | NoticeReadingResponse:
    notice = await readable_notice(db, notice_id, identity)

    return notice_response(notice) if identity.is_admin else reading_response(notice)


@router.get("/{notice_id}/attachments/{file_id}")
async def download_attachment(
    notice_id: int,
    file_id: int,
    identity: CurrentIdentity,
    db: DbSession,
) -> Response:
    await readable_notice(db, notice_id, identity)
    file = await notice_file(db, notice_id, file_id=file_id)

    return Response(
        content=file.content,
        media_type=file.content_type,
        headers={"Content-Disposition": inline_disposition(file.file_name)},
    )


@router.get("/{notice_id}/images/{image_key}")
async def get_image(
    notice_id: int,
    image_key: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> Response:
    await readable_notice(db, notice_id, identity)
    file = await notice_file(db, notice_id, image_key=image_key)

    return Response(content=file.content, media_type=file.content_type)


async def _mail(
    db: DbSession,
    background: BackgroundTasks,
    notice: Notice,
) -> None:
    people = await recipients_of(db, notice.recipients)
    notice.recipient_count = len(people)
    await db.commit()

    sent = await load_notice(db, notice.id, with_content=True)
    background.add_task(
        notice_mail.deliver,
        notice_mail.compose(sent, sent.files, unique_addresses(people)),
    )


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=NoticeResponse,
)
async def create_notice(
    identity: Administrator,
    db: DbSession,
    background: BackgroundTasks,
    title: Title,
    message: Message,
    recipients: Recipients,
    images: Images = None,
    attachments: Attachments = None,
) -> NoticeResponse:
    _, new_images = settle_images(message, (), await read_uploads(images))
    files = [*new_images, *attachments_of(await read_uploads(attachments))]
    check_total_size(files)

    notice = Notice(
        author_tax_code=identity.tax_code,
        title=title,
        message=message,
        recipients=_deduplicated(recipients),
        recipient_count=0,
        files=files,
    )
    db.add(notice)
    await db.flush()
    await _mail(db, background, notice)

    return notice_response(await load_notice(db, notice.id))


# A sent notice is sent again on every edit, saying it changed.
@router.put("/{notice_id}", response_model=NoticeResponse)
async def update_notice(
    notice_id: int,
    identity: Administrator,
    db: DbSession,
    background: BackgroundTasks,
    title: Title,
    message: Message,
    recipients: Recipients,
    kept_attachment_ids: Annotated[list[int] | None, Form()] = None,
    expected_updated_at: Annotated[datetime | None, Form()] = None,
    images: Images = None,
    attachments: Attachments = None,
) -> NoticeResponse:
    notice = await own_notice(db, notice_id, author_tax_code=identity.tax_code)
    assert_not_stale(notice, expected_updated_at, entity_label=_NOTICE_LABEL)

    kept_ids = set(kept_attachment_ids or ())
    kept_images, new_images = settle_images(
        message,
        [file for file in notice.files if file.image_key is not None],
        await read_uploads(images),
    )
    kept_attachments = [
        file
        for file in notice.files
        if file.image_key is None and file.id in kept_ids
    ]
    new_attachments = attachments_of(await read_uploads(attachments))

    files = [*kept_images, *new_images, *kept_attachments, *new_attachments]
    check_total_size(files)

    notice.title = title
    notice.message = message
    notice.recipients = _deduplicated(recipients)
    notice.files = files
    notice.edited_at = datetime.now(UTC)
    await db.flush()
    await _mail(db, background, notice)

    return notice_response(await load_notice(db, notice.id))


# Pinning again replaces the pin: a new day, or for good.
@router.put("/{notice_id}/pin", response_model=NoticeSummaryResponse)
async def pin_notice(
    notice_id: int,
    payload: NoticePinWrite,
    identity: Administrator,
    db: DbSession,
) -> NoticeSummaryResponse:
    notice = await load_notice(db, notice_id)

    if notice.pin is not None:
        await db.delete(notice.pin)
        await db.flush()

    db.add(
        NoticePin(
            notice_id=notice.id,
            pinned_by_tax_code=identity.tax_code,
            until=payload.until,
        )
    )
    await db.commit()

    return summary_response(await load_notice(db, notice_id))


@router.delete("/{notice_id}/pin", status_code=status.HTTP_204_NO_CONTENT)
async def unpin_notice(notice_id: int, _: Administrator, db: DbSession) -> Response:
    notice = await load_notice(db, notice_id)

    if notice.pin is not None:
        await db.delete(notice.pin)
        await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{notice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_notice(
    notice_id: int,
    identity: Administrator,
    db: DbSession,
) -> Response:
    notice = await own_notice(
        db,
        notice_id,
        author_tax_code=identity.tax_code,
        with_content=False,
    )

    await db.delete(notice)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
