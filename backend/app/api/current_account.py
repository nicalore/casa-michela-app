from typing import Annotated, Final

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.dependencies import DbSession
from app.core.security import decode_access_token
from app.models.account import Account
from app.repositories.account_repository import AccountRepository

bearer_scheme = HTTPBearer()

_INVALID_ACCESS_TOKEN_ERROR: Final[str] = "Token di accesso non valido"
_ACCOUNT_NOT_FOUND_ERROR: Final[str] = "Account non trovato"

_PASSWORD_RESET_REQUIRED_CODE: Final[str] = "PASSWORD_RESET_REQUIRED"


async def get_current_account(
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

    repository = AccountRepository(db)
    account = await repository.get_by_tax_code(payload["sub"])

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

CurrentAccount = Annotated[Account, Depends(get_current_active_account)]

CurrentAccountAllowPendingReset = Annotated[Account, Depends(get_current_account)]