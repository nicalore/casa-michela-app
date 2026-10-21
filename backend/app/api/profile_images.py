from typing import Final

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext
from app.core.storage import PROFILE_IMAGES_URL_PREFIX, profile_image_file
from app.models.member import Member
from app.models.person import Person
from app.models.staff import Staff
from app.services.role_service import RoleService

router = APIRouter(prefix=PROFILE_IMAGES_URL_PREFIX, tags=["profile-images"])

_NOT_FOUND_ERROR: Final[str] = "Foto non trovata"

_STAFF_READERS: Final[frozenset[str]] = frozenset({"TEACHER", "PSYCHOLOGIST"})

# Kept on the reader's device only; a new photo comes under a new name.
_CACHE_CONTROL: Final[str] = "private, max-age=86400"


async def _owner_of(db: AsyncSession, file_name: str) -> Person | None:
    member = joinedload(Person.member_profile)

    return await db.scalar(
        select(Person)
        .options(
            member.selectinload(Member.memberships),
            member.joinedload(Member.student_profile),
            member.joinedload(Member.staff_profile).joinedload(
                Staff.administrator_profile
            ),
        )
        .where(Person.profile_image_url == f"{PROFILE_IMAGES_URL_PREFIX}/{file_name}")
    )


# Enrolled staff show to everyone, enrolled pupils to the staff, children to parents.
def _shows_face(identity: IdentityContext, owner: Person) -> bool:
    if (
        identity.is_admin
        or owner.tax_code == identity.tax_code
        or owner.tax_code in identity.child_tax_codes
    ):
        return True

    member = owner.member_profile

    if member is None or not RoleService.in_good_standing(member):
        return False

    if member.staff_profile is not None:
        return True

    return member.student_profile is not None and not identity.roles.isdisjoint(
        _STAFF_READERS
    )


# Refused as missing, never 403: a name must not confirm that a photo exists.
@router.get("/{file_name}", response_class=FileResponse)
async def get_profile_image(
    file_name: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> FileResponse:
    path = profile_image_file(file_name)
    owner = None if path is None else await _owner_of(db, file_name)

    if (
        path is None
        or owner is None
        or not _shows_face(identity, owner)
        or not path.is_file()
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOT_FOUND_ERROR,
        )

    return FileResponse(
        path,
        media_type="image/jpeg",
        headers={"Cache-Control": _CACHE_CONTROL},
    )
