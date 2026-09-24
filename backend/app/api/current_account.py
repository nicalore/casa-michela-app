from typing import Annotated, Final

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.dependencies import DbSession
from app.core.security import decode_access_token
from app.models.account import Account
from app.repositories.identity_repository import IdentityRepository

bearer_scheme = HTTPBearer()

_INVALID_ACCESS_TOKEN_ERROR: Final[str] = "Token di accesso non valido"
_ACCOUNT_NOT_FOUND_ERROR: Final[str] = "Account non trovato"

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
            detail=_INVALID_ACCESS_TOKEN_ERROR,
        ) from None

    # Tells "this" session apart on the sessions routes; tokens issued before
    # sessions were tracked carry none.
    setattr(request.state, _SESSION_ID_STATE_KEY, payload.get("sid"))

    # With the role graph: every later dependency reads it off this object.
    account = await IdentityRepository(db).get_account_identity(payload["sub"])

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_ACCOUNT_NOT_FOUND_ERROR,
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
