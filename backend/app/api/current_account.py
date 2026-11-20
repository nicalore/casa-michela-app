from datetime import UTC, datetime
from typing import Annotated, Final

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.dependencies import DbSession
from app.core.i18n import tr
from app.core.security import decode_access_token
from app.models.account import Account, AccountStatusEnum
from app.repositories.identity_repository import IdentityRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.services.role_service import RoleService

bearer_scheme = HTTPBearer()

_INVALID_ACCESS_TOKEN_ERROR: Final[tuple[str, str]] = (
    "Token di accesso non valido",
    "Invalid access token",
)
_ACCOUNT_NOT_FOUND_ERROR: Final[tuple[str, str]] = (
    "Account non trovato",
    "Account not found",
)
_ACCOUNT_DISABLED_ERROR: Final[tuple[str, str]] = (
    "Account disabilitato",
    "Account disabled",
)
_SESSION_ENDED_ERROR: Final[tuple[str, str]] = (
    "Sessione terminata",
    "Session ended",
)

_PASSWORD_RESET_REQUIRED_CODE: Final[str] = "PASSWORD_RESET_REQUIRED"

_SESSION_ID_STATE_KEY: Final[str] = "session_id"


async def get_current_account(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: DbSession,
) -> Account:
    try:
        payload = decode_access_token(credentials.credentials)

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_INVALID_ACCESS_TOKEN_ERROR),
        ) from None

    # The sid is optional: a token without one is tied to no session.
    session_id = payload.get("sid")
    setattr(request.state, _SESSION_ID_STATE_KEY, session_id)

    # A session ended from another device stops at once, not when this token expires.
    if session_id is not None and not await RefreshTokenRepository(db).session_is_live(
        payload["sub"],
        session_id,
        datetime.now(UTC),
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_SESSION_ENDED_ERROR),
        )

    # With the role graph: every later dependency reads it off this object.
    account = await IdentityRepository(db).get_account_identity(payload["sub"])

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_ACCOUNT_NOT_FOUND_ERROR),
        )

    # A suspension takes effect at once, not when the access token expires.
    if (
        account.status != AccountStatusEnum.ACTIVE
        or RoleService.access_lapse(account.person) is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=tr(*_ACCOUNT_DISABLED_ERROR),
        )

    return account


async def get_current_active_account(
    account: Annotated[Account, Depends(get_current_account)],
) -> Account:
    if account.password_reset_required:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_PASSWORD_RESET_REQUIRED_CODE,
        )

    return account


# Depends on the account on purpose: the id is published while it is resolved.
async def get_current_session_id(
    request: Request,
    _: Annotated[Account, Depends(get_current_active_account)],
) -> str | None:
    return getattr(request.state, _SESSION_ID_STATE_KEY, None)


CurrentAccount = Annotated[Account, Depends(get_current_active_account)]

CurrentAccountAllowPendingReset = Annotated[Account, Depends(get_current_account)]

CurrentSessionId = Annotated[str | None, Depends(get_current_session_id)]
