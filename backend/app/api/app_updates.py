import re
from datetime import UTC, datetime
from typing import Annotated, Final

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload

from app.api.current_account import CurrentAccount
from app.api.dependencies import DbSession
from app.core import field_lengths
from app.core.optimistic_concurrency import assert_not_stale
from app.models.account import Account
from app.models.app_update import AppUpdate, AppUpdateRoleEnum
from app.schemas.app_update import (
    AppUpdateReadingResponse,
    AppUpdateRecipientsResponse,
    AppUpdateResponse,
    AppUpdatesSeenWrite,
    AppUpdateSummaryResponse,
)
from app.schemas.validators import CleanStr
from app.services.app_updates import (
    deduplicated,
    load_update,
    manages_updates,
    mark_read,
    people_reached,
    readable_ids,
    reading_response,
    settle_update_images,
    summary_response,
    unread_by,
    update_image,
    update_response,
)

_UPDATE_LABEL: Final[str] = "l'aggiornamento"
_NOT_A_MANAGER_ERROR: Final[str] = (
    "Solo i Responsabili IT gestiscono gli aggiornamenti."
)
_VERSION_ERROR: Final[str] = "La versione dell'app non è valida."

_VERSION: Final[re.Pattern[str]] = re.compile(r"\d+\.\d+\.\d+")

# Written, edited and deleted by any IT manager; shown once to every role it is for.
router = APIRouter(prefix="/app-updates", tags=["app-updates"])


def _manager(current_account: CurrentAccount) -> Account:
    if not manages_updates(current_account.person):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_NOT_A_MANAGER_ERROR,
        )

    return current_account


Manager = Annotated[Account, Depends(_manager)]

Title = Annotated[
    CleanStr,
    Form(min_length=1, max_length=field_lengths.NOTICE_TITLE),
]

Message = Annotated[
    CleanStr,
    Form(min_length=1, max_length=field_lengths.NOTICE_MESSAGE),
]

Recipients = Annotated[list[AppUpdateRoleEnum], Form(min_length=1)]

# Images of the message, each named by the key the message writes after image:.
Images = Annotated[list[UploadFile] | None, File()]


@router.get("/", response_model=list[AppUpdateSummaryResponse])
async def list_updates(_: Manager, db: DbSession) -> list[AppUpdateSummaryResponse]:
    updates = await db.scalars(
        select(AppUpdate)
        .options(joinedload(AppUpdate.author), selectinload(AppUpdate.images))
        .order_by(AppUpdate.created_at.desc(), AppUpdate.id.desc())
    )

    return [summary_response(update) for update in updates]


@router.get("/recipients", response_model=AppUpdateRecipientsResponse)
async def count_recipients(
    _: Manager,
    db: DbSession,
    recipients: Annotated[list[AppUpdateRoleEnum] | None, Query()] = None,
) -> AppUpdateRecipientsResponse:
    return AppUpdateRecipientsResponse(
        people=await people_reached(db, recipients or ()),
    )


# What the caller has still to read, the newest first.
@router.get("/unread", response_model=list[AppUpdateReadingResponse])
async def unread_updates(
    current_account: CurrentAccount,
    db: DbSession,
) -> list[AppUpdateReadingResponse]:
    return [
        reading_response(update) for update in await unread_by(db, current_account)
    ]


# Read on closing the message; ids gone in the meantime are passed over.
@router.put("/seen", status_code=status.HTTP_204_NO_CONTENT)
async def updates_seen(
    payload: AppUpdatesSeenWrite,
    current_account: CurrentAccount,
    db: DbSession,
) -> Response:
    ids = await readable_ids(db, current_account.person, payload.ids)
    await mark_read(db, current_account.tax_code, ids)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{update_id}", response_model=AppUpdateResponse)
async def get_update(update_id: int, _: Manager, db: DbSession) -> AppUpdateResponse:
    return update_response(await load_update(db, update_id))


@router.get("/{update_id}/images/{image_key}")
async def get_image(
    update_id: int,
    image_key: str,
    current_account: CurrentAccount,
    db: DbSession,
) -> Response:
    image = await update_image(db, current_account.person, update_id, image_key)

    return Response(content=image.content, media_type=image.content_type)


# The version is the publishing app's own; its author has read it already.
@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    response_model=AppUpdateResponse,
)
async def create_update(
    manager: Manager,
    db: DbSession,
    title: Title,
    message: Message,
    recipients: Recipients,
    version: Annotated[CleanStr, Form(max_length=field_lengths.APP_VERSION)],
    images: Images = None,
) -> AppUpdateResponse:
    if not _VERSION.fullmatch(version):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_VERSION_ERROR,
        )

    update = AppUpdate(
        author_tax_code=manager.tax_code,
        title=title,
        message=message,
        version=version,
        recipients=deduplicated(recipients),
        images=[],
    )
    await settle_update_images(update, images)
    db.add(update)
    await db.flush()
    await mark_read(db, manager.tax_code, [update.id])
    await db.commit()

    return update_response(await load_update(db, update.id))


# Shown in its new words only to those who have not read it; the version stays.
@router.put("/{update_id}", response_model=AppUpdateResponse)
async def edit_update(
    update_id: int,
    manager: Manager,
    db: DbSession,
    title: Title,
    message: Message,
    recipients: Recipients,
    expected_updated_at: Annotated[datetime | None, Form()] = None,
    images: Images = None,
) -> AppUpdateResponse:
    update = await load_update(db, update_id)
    assert_not_stale(update, expected_updated_at, entity_label=_UPDATE_LABEL)

    update.title = title
    update.message = message
    update.recipients = deduplicated(recipients)
    update.edited_at = datetime.now(UTC)
    await settle_update_images(update, images)
    await mark_read(db, manager.tax_code, [update.id])
    await db.commit()

    return update_response(await load_update(db, update.id))


# Gone for good, for those who had not read it too.
@router.delete("/{update_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_update(update_id: int, _: Manager, db: DbSession) -> Response:
    await db.delete(await load_update(db, update_id))
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
