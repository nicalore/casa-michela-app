from datetime import UTC, datetime
from typing import Annotated, Any, Final

from fastapi import (
    APIRouter,
    BackgroundTasks,
    File,
    HTTPException,
    Request,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.current_account import (
    CurrentAccount,
    CurrentAccountAllowPendingReset,
    CurrentSessionId,
)
from app.api.dependencies import DbSession
from app.api.rbac import worn_role
from app.core.client_device import (
    DEVICE_KEY_HEADER,
    FORM_FACTOR_HEADER,
    ClientDevice,
    describe_client,
)
from app.core.i18n import tr
from app.core.password_policy import PasswordPolicyError
from app.core.storage import discard_profile_image, store_profile_image
from app.models.account import Account
from app.models.person import Person
from app.repositories.account_repository import AccountRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.schemas.auth.active_role_request import ActiveRoleRequest
from app.schemas.auth.change_password_request import ChangePasswordRequest
from app.schemas.auth.colour_theme_request import ColourThemeRequest
from app.schemas.auth.language_request import LanguageRequest
from app.schemas.auth.login_request import LoginRequest
from app.schemas.auth.login_response import LoginResponse
from app.schemas.auth.logout_request import LogoutRequest
from app.schemas.auth.password_reset import (
    PasswordResetConfirm,
    PasswordResetRequest,
    PasswordResetToken,
)
from app.schemas.auth.refresh_request import RefreshRequest
from app.schemas.auth.session_response import SessionResponse
from app.schemas.auth.theme_mode_request import ThemeModeRequest
from app.services import push
from app.services.app_updates import manages_updates
from app.services.auth_service import (
    AccountDisabledError,
    AccountLockedError,
    AuthenticationError,
    AuthService,
    InvalidRefreshTokenError,
    PasswordChangeExpiredError,
    PasswordReuseError,
    SessionNotFoundError,
)
from app.services.new_devices import device_seen, sessions_ended
from app.services.report_readers import kinds_read_by
from app.services.role_service import BOARD_ROLES, RoleService
from app.services.terms import (
    latest_terms_request,
    record_terms_acceptance,
    terms_due,
    terms_update_shown,
)

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

_INVALID_CREDENTIALS_ERROR: Final[tuple[str, str]] = (
    "Nome utente o password non validi",
    "Invalid username or password",
)
_ACCOUNT_DISABLED_ERROR: Final[tuple[str, str]] = (
    "Account disabilitato",
    "Account disabled",
)
_ACCOUNT_LOCKED_ERROR: Final[tuple[str, str]] = (
    "Account temporaneamente bloccato fino al {locked_until}",
    "Account temporarily locked until {locked_until}",
)
_INVALID_REFRESH_TOKEN_ERROR: Final[tuple[str, str]] = (
    "Token di sessione non valido",
    "Invalid session token",
)
# Mirrored by frontend/lib/services/api_service.dart.
_PASSWORD_CHANGE_EXPIRED_CODE: Final[str] = "PASSWORD_CHANGE_EXPIRED"
_CURRENT_SESSION_ERROR: Final[tuple[str, str]] = (
    "La sessione in uso si chiude con l'uscita",
    "The current session is closed by signing out",
)
_SESSION_NOT_FOUND_ERROR: Final[tuple[str, str]] = (
    "Sessione non trovata o già disattivata",
    "Session not found or already turned off",
)
_UNKNOWN_CURRENT_SESSION_ERROR: Final[tuple[str, str]] = (
    "Sessione in uso non riconosciuta: esci e accedi di nuovo",
    "Current session not recognised: sign out and sign in again",
)

_ROLE_NOT_AVAILABLE_ERROR: Final[tuple[str, str]] = (
    "Ruolo non disponibile per questo account",
    "Role not available for this account",
)
_ROLE_WITHOUT_UI_ERROR: Final[tuple[str, str]] = (
    "L'area dedicata a questo ruolo non è ancora disponibile",
    "The area for this role isn't available yet",
)
_CURRENT_PASSWORD_ERROR: Final[tuple[str, str]] = (
    "La password attuale non è corretta",
    "The current password is incorrect",
)
_PASSWORD_REUSE_ERROR: Final[tuple[str, str]] = (
    "La nuova password non può coincidere con quella attuale.",
    "The new password can't be the same as the current one.",
)
_INVALID_IMAGE_TYPE_ERROR: Final[tuple[str, str]] = (
    "Sono ammesse solo immagini JPEG, PNG e WEBP",
    "Only JPEG, PNG and WEBP images are allowed",
)
_MISSING_FILENAME_ERROR: Final[tuple[str, str]] = (
    "Nome del file mancante",
    "File name missing",
)
_NO_PROFILE_IMAGE_ERROR: Final[tuple[str, str]] = (
    "Nessuna immagine del profilo da rimuovere",
    "No profile picture to remove",
)
_INVALID_RESET_TOKEN_ERROR: Final[tuple[str, str]] = (
    "Token di reimpostazione non valido o scaduto",
    "Reset token invalid or expired",
)

_PASSWORD_RESET_REQUESTED_MESSAGE: Final[tuple[str, str]] = (
    "Se l'indirizzo email esiste, è stato inviato un link di recupero.",
    "If the email address exists, a recovery link has been sent.",
)
_PASSWORD_RESET_DONE_MESSAGE: Final[tuple[str, str]] = (
    "Password reimpostata correttamente.",
    "Password reset successfully.",
)


def _build_auth_service(db: AsyncSession) -> AuthService:
    return AuthService(
        AccountRepository(db),
        RefreshTokenRepository(db),
    )


def _client_device(request: Request) -> ClientDevice:
    return describe_client(
        request.headers.get("user-agent"),
        request.headers.get(FORM_FACTOR_HEADER),
    )


# A sign-in from a device the account never used is told to the account.
@router.post("/login", response_model=LoginResponse)
async def login(
    request: LoginRequest,
    http_request: Request,
    db: DbSession,
    background: BackgroundTasks,
) -> LoginResponse:
    auth_service = _build_auth_service(db)
    device = _client_device(http_request)

    try:
        result = await auth_service.authenticate(
            username=request.username,
            password=request.password,
            device=device,
        )
        told = await device_seen(
            db,
            result.account_tax_code,
            http_request.headers.get(DEVICE_KEY_HEADER),
            session_id=result.session_id,
            device_name=device.name,
        )
        await db.commit()
        background.add_task(push.deliver, told)

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=result.password_reset_required,
        )

    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_INVALID_CREDENTIALS_ERROR),
        ) from None
    except AccountDisabledError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=tr(*_ACCOUNT_DISABLED_ERROR),
        ) from None
    except AccountLockedError as err:
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=tr(*_ACCOUNT_LOCKED_ERROR).format(locked_until=err.locked_until),
        ) from None


@router.post("/refresh", response_model=LoginResponse)
async def refresh(
    request: RefreshRequest,
    http_request: Request,
    db: DbSession,
) -> LoginResponse:
    auth_service = _build_auth_service(db)

    try:
        result = await auth_service.refresh(
            request.refresh_token,
            device=_client_device(http_request),
        )
        # Recorded without a notice, so a device already signed in becomes known.
        await device_seen(
            db,
            result.account_tax_code,
            http_request.headers.get(DEVICE_KEY_HEADER),
        )
        await db.commit()

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=result.password_reset_required,
        )
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_INVALID_REFRESH_TOKEN_ERROR),
        ) from None
    except PasswordChangeExpiredError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_PASSWORD_CHANGE_EXPIRED_CODE,
        ) from None


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(request: LogoutRequest, db: DbSession) -> None:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.logout(request.refresh_token)
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_INVALID_REFRESH_TOKEN_ERROR),
        ) from None


@router.get("/sessions", response_model=list[SessionResponse])
async def list_sessions(
    current_account: CurrentAccount,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> list[SessionResponse]:
    sessions = await _build_auth_service(db).list_sessions(current_account.tax_code)

    items = [
        SessionResponse(
            session_id=session.session_id,
            logged_in_at=session.logged_in_at,
            # The live token is the one the last refresh issued.
            last_used_at=session.created_at,
            device_type=session.device_type,
            device_name=session.device_name,
            current=session.session_id == current_session_id,
        )
        for session in sessions
    ]

    # This session first; the rest stay most recently used first.
    return sorted(items, key=lambda item: not item.current)


@router.delete("/sessions", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_other_sessions(
    current_account: CurrentAccount,
    current_session_id: CurrentSessionId,
    db: DbSession,
    background: BackgroundTasks,
) -> None:
    # A token without a sid names no session to keep.
    if current_session_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_UNKNOWN_CURRENT_SESSION_ERROR),
        )

    await _build_auth_service(db).revoke_other_sessions(
        current_account.tax_code,
        current_session_id,
    )
    told = await sessions_ended(
        db,
        current_account.tax_code,
        keep=current_session_id,
    )
    await db.commit()
    background.add_task(push.deliver, told)


# The session in use ends with a logout, which clears the client as well.
@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_session(
    session_id: str,
    current_account: CurrentAccount,
    current_session_id: CurrentSessionId,
    db: DbSession,
    background: BackgroundTasks,
) -> None:
    if session_id == current_session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_CURRENT_SESSION_ERROR),
        )

    try:
        await _build_auth_service(db).revoke_session(
            current_account.tax_code,
            session_id,
        )
    except SessionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=tr(*_SESSION_NOT_FOUND_ERROR),
        ) from None

    told = await sessions_ended(db, current_account.tax_code, sessions=[session_id])
    await db.commit()
    background.add_task(push.deliver, told)


# The board seat, if any; None otherwise, even for an OTHER-role administrator.
def _board_role(person: Person) -> str | None:
    member = person.member_profile
    staff = member.staff_profile if member is not None else None
    administrator = staff.administrator_profile if staff is not None else None

    if administrator is None or administrator.role not in BOARD_ROLES:
        return None

    return administrator.role.value


def _identity_payload(
    account: Account,
    terms_requested_at: datetime | None,
    worn: str | None = None,
) -> dict[str, Any]:
    person = account.person
    roles = RoleService.sorted_by_label(RoleService.get_available_roles(person))

    active_role = RoleService.resolve_active_role(
        roles,
        account.last_active_role,
        worn,
    )

    has_address = bool(person.residence_type and person.residence_address)
    address = f"{person.residence_type} {person.residence_address}".strip()
    updated_at = terms_update_shown(account, terms_requested_at)

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
        # Asked in the first-access flow, or alone to those already past it.
        "terms_required": terms_due(account, terms_requested_at),
        # The request that asks again someone who had accepted, shown with its date.
        "terms_updated_at": updated_at.isoformat() if updated_at else None,
        # A pupil somebody answers for: parents book and pay, so their area is smaller.
        "has_parental_responsibility": RoleService.is_answered_for(person),
        # Such a pupil may still be allowed to book; payments stay with the parents.
        "autonomous_bookings": account.autonomous_bookings,
        "colour_theme": account.colour_theme.value,
        "theme_mode": account.theme_mode.value,
        # Null until chosen: each device keeps its own until then.
        "language": account.language.value if account.language else None,
        "board_role": _board_role(person),
        # The kinds of report they receive; their menu lists them if any.
        "report_kinds": [kind.value for kind in kinds_read_by(person)],
        # IT managers write the app's updates; their menu has the page.
        "manages_updates": manages_updates(person),
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
async def me(
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    return _identity_payload(
        current_account,
        await latest_terms_request(db),
        worn_role(request),
    )


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
            detail=tr(*_ROLE_NOT_AVAILABLE_ERROR),
        )

    if role not in RoleService.ROLES_WITH_UI:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_ROLE_WITHOUT_UI_ERROR),
        )

    account.last_active_role = role

    await db.commit()

    return _identity_payload(account, await latest_terms_request(db))


# Every device of the account follows; sign-in pages keep Casa Michela's colours.
@router.put("/colour-theme")
async def set_colour_theme(
    payload: ColourThemeRequest,
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account
    account.colour_theme = payload.colour_theme

    await db.commit()

    return _identity_payload(
        account,
        await latest_terms_request(db),
        worn_role(request),
    )


# Like the colours: every device follows, sign-in pages stay light.
@router.put("/theme-mode")
async def set_theme_mode(
    payload: ThemeModeRequest,
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account
    account.theme_mode = payload.theme_mode

    await db.commit()

    return _identity_payload(
        account,
        await latest_terms_request(db),
        worn_role(request),
    )


# Like the colours: every device follows; sign-in pages keep the device's last one.
@router.put("/language")
async def set_language(
    payload: LanguageRequest,
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account
    account.language = payload.language

    await db.commit()

    return _identity_payload(
        account,
        await latest_terms_request(db),
        worn_role(request),
    )


# Only reaching the end writes anything; abandoning halfway restarts the flow.
@router.post("/complete-onboarding")
async def complete_onboarding(
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account

    if account.onboarding_completed_at is None:
        account.onboarding_completed_at = datetime.now(UTC)

        await db.commit()

    return _identity_payload(
        account,
        await latest_terms_request(db),
        worn_role(request),
    )


# An acceptance still current keeps its date; past a newer request it moves.
@router.post("/accept-terms")
async def accept_terms(
    request: Request,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, Any]:
    account = current_account
    requested_at = await latest_terms_request(db)

    record_terms_acceptance(db, account, requested_at)

    await db.commit()

    return _identity_payload(account, requested_at, worn_role(request))


@router.post("/profile-image")
async def upload_profile_image(
    current_account: CurrentAccount,
    db: DbSession,
    file: Annotated[UploadFile, File()],
) -> dict[str, str]:
    if file.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_INVALID_IMAGE_TYPE_ERROR),
        )

    if file.filename is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_MISSING_FILENAME_ERROR),
        )

    profile_image_url = store_profile_image(
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
            detail=tr(*_NO_PROFILE_IMAGE_ERROR),
        )

    person.profile_image_url = None

    await db.commit()

    discard_profile_image(profile_image_url)


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
            detail=tr(*_CURRENT_PASSWORD_ERROR),
        ) from None
    except PasswordReuseError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_PASSWORD_REUSE_ERROR),
        ) from None
    except PasswordPolicyError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from None
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_INVALID_REFRESH_TOKEN_ERROR),
        ) from None
    except PasswordChangeExpiredError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_PASSWORD_CHANGE_EXPIRED_CODE,
        ) from None


@router.post("/request-password-reset")
async def request_password_reset(
    request: PasswordResetRequest,
    db: DbSession,
) -> dict[str, str]:
    auth_service = _build_auth_service(db)

    await auth_service.request_password_reset(username=request.username)

    return {"message": tr(*_PASSWORD_RESET_REQUESTED_MESSAGE)}


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

    return {"message": tr(*_PASSWORD_RESET_DONE_MESSAGE)}


# A POST body, not a query: request lines end up in access logs.
@router.post("/validate-reset-token")
async def validate_reset_token(
    payload: PasswordResetToken,
    db: DbSession,
) -> dict[str, bool]:
    auth_service = _build_auth_service(db)

    try:
        await auth_service.validate_reset_token(token=payload.token)
    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=tr(*_INVALID_RESET_TOKEN_ERROR),
        ) from None

    return {"valid": True}