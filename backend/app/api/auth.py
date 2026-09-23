from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated, Any, Final

from fastapi import (
    APIRouter,
    File,
    HTTPException,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.current_account import CurrentAccount, CurrentAccountAllowPendingReset
from app.api.dependencies import DbSession
from app.core.password_policy import PasswordPolicyError
from app.core.storage import PROFILE_IMAGES_DIR, store_profile_image
from app.models.account import Account
from app.models.administrator import AdministratorRoleEnum
from app.models.person import Person
from app.repositories.account_repository import AccountRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.schemas.auth.active_role_request import ActiveRoleRequest
from app.schemas.auth.change_password_request import ChangePasswordRequest
from app.schemas.auth.login_request import LoginRequest
from app.schemas.auth.login_response import LoginResponse
from app.schemas.auth.logout_request import LogoutRequest
from app.schemas.auth.password_reset import PasswordResetConfirm, PasswordResetRequest
from app.schemas.auth.refresh_request import RefreshRequest
from app.services.auth_service import (
    AccountDisabledError,
    AccountLockedError,
    AuthenticationError,
    AuthService,
    InvalidRefreshTokenError,
    PasswordReuseError,
)
from app.services.role_service import RoleService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

_ALLOWED_IMAGE_TYPES: Final[frozenset[str]] = frozenset(
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    }
)

_INVALID_CREDENTIALS_ERROR: Final[str] = "Nome utente o password non validi"
_ACCOUNT_DISABLED_ERROR: Final[str] = "Account disabilitato"
_ACCOUNT_LOCKED_ERROR: Final[str] = (
    "Account temporaneamente bloccato fino al {locked_until}"
)
_INVALID_REFRESH_TOKEN_ERROR: Final[str] = "Token di sessione non valido"

# Mirrored by frontend/lib/features/auth/models/me_response.dart.
_BOARD_ROLES: Final[frozenset[AdministratorRoleEnum]] = frozenset(
    {
        AdministratorRoleEnum.PRESIDENT,
        AdministratorRoleEnum.VICE_PRESIDENT,
        AdministratorRoleEnum.TREASURER,
    }
)
_ROLE_NOT_AVAILABLE_ERROR: Final[str] = "Ruolo non disponibile per questo account"
_ROLE_WITHOUT_UI_ERROR: Final[str] = (
    "L'area dedicata a questo ruolo non è ancora disponibile"
)
_CURRENT_PASSWORD_ERROR: Final[str] = "La password attuale non è corretta"
_PASSWORD_REUSE_ERROR: Final[str] = (
    "La nuova password non può coincidere con quella attuale."
)
_INVALID_IMAGE_TYPE_ERROR: Final[str] = "Sono ammesse solo immagini JPEG, PNG e WEBP"
_MISSING_FILENAME_ERROR: Final[str] = "Nome del file mancante"
_NO_PROFILE_IMAGE_ERROR: Final[str] = "Nessuna immagine del profilo da rimuovere"
_INVALID_RESET_TOKEN_ERROR: Final[str] = (
    "Token di reimpostazione non valido o scaduto"
)

_PASSWORD_RESET_REQUESTED_MESSAGE: Final[str] = (
    "Se l'indirizzo email esiste, è stato inviato un link di recupero."
)
_PASSWORD_RESET_DONE_MESSAGE: Final[str] = "Password reimpostata correttamente."


def _build_auth_service(db: AsyncSession) -> AuthService:
    return AuthService(
        AccountRepository(db),
        RefreshTokenRepository(db),
    )


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: DbSession) -> LoginResponse:
    auth_service = _build_auth_service(db)

    try:
        result = await auth_service.authenticate(
            username=request.username,
            password=request.password,
        )

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=result.password_reset_required,
        )

    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_INVALID_CREDENTIALS_ERROR,
        ) from None
    except AccountDisabledError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_ACCOUNT_DISABLED_ERROR,
        ) from None
    except AccountLockedError as err:
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=_ACCOUNT_LOCKED_ERROR.format(locked_until=err.locked_until),
        ) from None


@router.post("/refresh", response_model=LoginResponse)
async def refresh(request: RefreshRequest, db: DbSession) -> LoginResponse:
    auth_service = _build_auth_service(db)

    try:
        result = await auth_service.refresh(request.refresh_token)

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=result.password_reset_required,
        )
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_INVALID_REFRESH_TOKEN_ERROR,
        ) from None


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(request: LogoutRequest, db: DbSession) -> None:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.logout(request.refresh_token)
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_INVALID_REFRESH_TOKEN_ERROR,
        ) from None


# The board seat, if any; None otherwise, even for an OTHER-role administrator.
def _board_role(person: Person) -> str | None:
    member = person.member_profile
    staff = member.staff_profile if member is not None else None
    administrator = staff.administrator_profile if staff is not None else None

    if administrator is None or administrator.role not in _BOARD_ROLES:
        return None

    return administrator.role.value


# Only a pupil is answered for: a minor on the staff has parents for paperwork alone.
def _is_answered_for(person: Person) -> bool:
    member = person.member_profile

    return (
        member is not None
        and member.student_profile is not None
        and bool(person.parental_relationships)
    )


def _identity_payload(account: Account) -> dict[str, Any]:
    person = account.person
    roles = RoleService.sorted_by_label(RoleService.get_available_roles(person))

    active_role = RoleService.resolve_active_role(roles, account.last_active_role)

    has_address = bool(person.residence_type and person.residence_address)
    address = f"{person.residence_type} {person.residence_address}".strip()

    return {
        "tax_code": account.tax_code,
        "username": account.username,
        "first_name": person.first_name,
        "last_name": person.last_name,
        "full_name": f"{person.first_name} {person.last_name}",
        "profile_image_url": person.profile_image_url,
        "available_roles": roles,
        "active_role": active_role,
        "status": account.status,
        "password_reset_required": account.password_reset_required,
        # Stays required until the whole flow ends; the password change is step one.
        "onboarding_required": account.onboarding_completed_at is None,
        # A pupil somebody answers for: parents book and pay, so their area is narrower.
        "has_parental_responsibility": _is_answered_for(person),
        "board_role": _board_role(person),
        # Stored aware, in UTC; the client picks the wall clock.
        "last_login": account.last_login.isoformat() if account.last_login else None,
        "gender": person.gender.value if person.gender else None,
        "email": person.email,
        "phone_number": person.phone,
        "birth_date": person.birth_date.isoformat() if person.birth_date else None,
        "birth_city": person.birth_city,
        "birth_province": person.birth_province,
        "address": address if has_address else None,
        "address_number": person.residence_street_number,
        "city": person.residence_city,
        "province": person.residence_province,
        "zip_code": person.postal_code,
    }


@router.get("/me")
async def me(current_account: CurrentAccount) -> dict[str, Any]:
    return _identity_payload(current_account)


# Presentation only: RBAC still reads every role, so switching changes no permission.
@router.put("/active-role")
async def set_active_role(
    request: ActiveRoleRequest,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account
    role = request.role

    if role not in RoleService.get_available_roles(account.person):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ROLE_NOT_AVAILABLE_ERROR,
        )

    if role not in RoleService.ROLES_WITH_UI:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_ROLE_WITHOUT_UI_ERROR,
        )

    account.last_active_role = role

    await db.commit()

    return _identity_payload(account)


# Only reaching the end writes anything; abandoning halfway restarts the flow.
@router.post("/complete-onboarding")
async def complete_onboarding(
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account

    if account.onboarding_completed_at is None:
        account.onboarding_completed_at = datetime.now(UTC)

        await db.commit()

    return _identity_payload(account)


@router.post("/profile-image")
async def upload_profile_image(
    current_account: CurrentAccount,
    db: DbSession,
    file: Annotated[UploadFile, File()],
) -> dict[str, str]:
    if file.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_INVALID_IMAGE_TYPE_ERROR,
        )

    if file.filename is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MISSING_FILENAME_ERROR,
        )

    profile_image_url = store_profile_image(
        current_account.tax_code,
        current_account.person.profile_image_url,
        await file.read(),
    )
    current_account.person.profile_image_url = profile_image_url

    await db.commit()

    return {"profile_image_url": profile_image_url}


@router.delete("/profile-image", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile_image(
    current_account: CurrentAccount,
    db: DbSession,
) -> None:
    person = current_account.person
    profile_image_url = person.profile_image_url

    if profile_image_url is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NO_PROFILE_IMAGE_ERROR,
        )

    file_path = PROFILE_IMAGES_DIR / Path(profile_image_url).name

    if file_path.exists():
        file_path.unlink()

    person.profile_image_url = None

    await db.commit()


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    request: ChangePasswordRequest,
    current_account: CurrentAccountAllowPendingReset,
    db: DbSession,
) -> None:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.change_password(
            account=current_account,
            current_password=request.current_password,
            new_password=request.new_password,
            refresh_token=request.refresh_token,
        )
    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CURRENT_PASSWORD_ERROR,
        ) from None
    except PasswordReuseError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_PASSWORD_REUSE_ERROR,
        ) from None
    except PasswordPolicyError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from None
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_INVALID_REFRESH_TOKEN_ERROR,
        ) from None


@router.post("/request-password-reset")
async def request_password_reset(
    request: PasswordResetRequest,
    db: DbSession,
) -> dict[str, str]:
    auth_service = _build_auth_service(db)

    await auth_service.request_password_reset(username=request.username)

    return {"message": _PASSWORD_RESET_REQUESTED_MESSAGE}


@router.post("/reset-password")
async def reset_password(
    request: PasswordResetConfirm,
    db: DbSession,
) -> dict[str, str]:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.reset_password(
            token=request.token,
            new_password=request.new_password,
        )
    except AuthenticationError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from None
    except PasswordPolicyError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from None

    return {"message": _PASSWORD_RESET_DONE_MESSAGE}


@router.get("/validate-reset-token")
async def validate_reset_token(token: str, db: DbSession) -> dict[str, bool]:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.validate_reset_token(token=token)
    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_INVALID_RESET_TOKEN_ERROR,
        ) from None

    return {"valid": True}