from collections.abc import Iterable, Sequence
from typing import Final

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import exists, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload, undefer

from app.models.account import Account, AccountStatusEnum
from app.models.administrator import AdministratorRoleEnum
from app.models.app_update import (
    AppUpdate,
    AppUpdateImage,
    AppUpdateRead,
    AppUpdateRoleEnum,
)
from app.models.notice import NoticeRoleEnum
from app.models.person import Person
from app.schemas.app_update import (
    AppUpdateImageResponse,
    AppUpdateReadingResponse,
    AppUpdateResponse,
    AppUpdateSummaryResponse,
)
from app.services.notice_markdown import preview
from app.services.notice_recipients import recipients_of
from app.services.notices import MAX_FILES_BYTES, Upload, read_uploads, settle_images
from app.services.report_readers import reader_role
from app.services.role_service import RoleService

_UPDATE_NOT_FOUND_ERROR: Final[str] = "Aggiornamento non trovato"
_IMAGE_NOT_FOUND_ERROR: Final[str] = "Immagine non trovata"
_TOO_LARGE_ERROR: Final[str] = "Le immagini superano i 15 MB totali."


# Only while the administrator's role holds, as for the reports.
def manages_updates(person: Person) -> bool:
    return reader_role(person) == AdministratorRoleEnum.IT_MANAGER


# Every role held, whichever is worn.
def update_roles_of(person: Person) -> list[AppUpdateRoleEnum]:
    held = set(RoleService.get_available_roles(person))

    return [role for role in AppUpdateRoleEnum if role.value in held]


def deduplicated(roles: Iterable[AppUpdateRoleEnum]) -> list[AppUpdateRoleEnum]:
    wanted = set(roles)

    return [role for role in AppUpdateRoleEnum if role in wanted]


def _name(person: Person) -> str:
    return f"{person.first_name} {person.last_name}"


def _images(update: AppUpdate) -> list[AppUpdateImageResponse]:
    return [
        AppUpdateImageResponse(key=image.image_key, size=image.size)
        for image in update.images
    ]


def summary_response(update: AppUpdate) -> AppUpdateSummaryResponse:
    return AppUpdateSummaryResponse(
        id=update.id,
        title=update.title,
        version=update.version,
        preview=preview(update.message),
        author_name=_name(update.author),
        recipients=deduplicated(update.recipients),
        created_at=update.created_at,
        edited_at=update.edited_at,
    )


def update_response(update: AppUpdate) -> AppUpdateResponse:
    return AppUpdateResponse(
        **summary_response(update).model_dump(),
        message=update.message,
        images=_images(update),
        updated_at=update.updated_at,
    )


def reading_response(update: AppUpdate) -> AppUpdateReadingResponse:
    return AppUpdateReadingResponse(
        id=update.id,
        title=update.title,
        version=update.version,
        message=update.message,
        images=_images(update),
    )


async def load_update(db: AsyncSession, update_id: int) -> AppUpdate:
    update = await db.scalar(
        select(AppUpdate)
        .options(joinedload(AppUpdate.author), selectinload(AppUpdate.images))
        .where(AppUpdate.id == update_id)
        .execution_options(populate_existing=True)
    )

    if update is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_UPDATE_NOT_FOUND_ERROR,
        )

    return update


def _stored(upload: Upload, image_key: str) -> AppUpdateImage:
    return AppUpdateImage(
        image_key=image_key,
        content_type=upload.content_type,
        size=len(upload.content),
        content=upload.content,
    )


# The images the message shows: those kept, then the new ones; the others go.
async def settle_update_images(
    update: AppUpdate,
    uploads: Sequence[UploadFile] | None,
) -> None:
    kept, added = settle_images(
        update.message,
        {image.image_key: image for image in update.images},
        await read_uploads(uploads, too_large=_TOO_LARGE_ERROR),
        _stored,
    )
    images = [*kept, *added]

    if sum(image.size for image in images) > MAX_FILES_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=_TOO_LARGE_ERROR,
        )

    update.images = images


# Newest first: those for a role held, published since the account exists, not read.
async def unread_by(db: AsyncSession, account: Account) -> list[AppUpdate]:
    roles = update_roles_of(account.person)

    if not roles:
        return []

    read = exists().where(
        AppUpdateRead.update_id == AppUpdate.id,
        AppUpdateRead.account_tax_code == account.tax_code,
    )
    updates = await db.scalars(
        select(AppUpdate)
        .options(selectinload(AppUpdate.images))
        .where(
            AppUpdate.recipients.overlap(roles),
            AppUpdate.created_at >= account.created_at,
            ~read,
        )
        .order_by(AppUpdate.created_at.desc(), AppUpdate.id.desc())
    )

    return list(updates)


async def mark_read(db: AsyncSession, tax_code: str, ids: Iterable[int]) -> None:
    rows = [{"update_id": update_id, "account_tax_code": tax_code} for update_id in ids]

    if rows:
        await db.execute(insert(AppUpdateRead).values(rows).on_conflict_do_nothing())


# Of those asked, the ones still there that were meant for the reader.
async def readable_ids(
    db: AsyncSession,
    person: Person,
    ids: Iterable[int],
) -> list[int]:
    roles = update_roles_of(person)

    if not roles:
        return []

    found = await db.scalars(
        select(AppUpdate.id).where(
            AppUpdate.id.in_(set(ids)),
            AppUpdate.recipients.overlap(roles),
        )
    )

    return list(found)


async def update_image(
    db: AsyncSession,
    person: Person,
    update_id: int,
    image_key: str,
) -> AppUpdateImage:
    if not manages_updates(person) and not await readable_ids(db, person, [update_id]):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_UPDATE_NOT_FOUND_ERROR,
        )

    image = await db.scalar(
        select(AppUpdateImage)
        .options(undefer(AppUpdateImage.content))
        .where(
            AppUpdateImage.update_id == update_id,
            AppUpdateImage.image_key == image_key,
        )
    )

    if image is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_IMAGE_NOT_FOUND_ERROR,
        )

    return image


# People holding one of the roles today who can sign in.
async def people_reached(db: AsyncSession, roles: Iterable[AppUpdateRoleEnum]) -> int:
    people = await recipients_of(db, [NoticeRoleEnum(role.value) for role in roles])

    if not people:
        return 0

    return (
        await db.scalar(
            select(func.count())
            .select_from(Account)
            .where(
                Account.tax_code.in_([person.tax_code for person in people]),
                Account.status == AccountStatusEnum.ACTIVE,
            )
        )
        or 0
    )
