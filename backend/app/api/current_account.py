from typing import Annotated

from fastapi import (
    Depends,
    HTTPException,
    status,
)
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
)

from app.api.dependencies import DbSession
from app.core.security import (
    decode_access_token,
)
from app.models.account import Account
from app.repositories.account_repository import (
    AccountRepository,
)

bearer_scheme = HTTPBearer()


async def get_current_account(
    credentials: Annotated[
        HTTPAuthorizationCredentials,
        Depends(bearer_scheme),
    ],
    db: DbSession,
) -> Account:
    token = credentials.credentials

    try:
        payload = decode_access_token(
            token
        )

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
        ) from None

    repository = AccountRepository(
        db,
    )

    account = (
        await repository.get_by_tax_code(
            payload["sub"]
        )
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account not found",
        )

    return account


async def get_current_active_account(
    account: Annotated[
        Account,
        Depends(get_current_account),
    ],
) -> Account:
    if account.password_reset_required:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="PASSWORD_RESET_REQUIRED",
        )

    return account


# Da usare per la quasi totalità degli endpoint dell'area riservata.
# Blocca con 403 chiunque abbia il reset password obbligatorio pendente,
# a prescindere dalla validità del token (RF-IAM-012).
CurrentAccount = Annotated[
    Account,
    Depends(get_current_active_account),
]

# Da usare SOLO per gli endpoint che devono restare accessibili anche con
# reset password pendente: l'endpoint di cambio password stesso, e
# logout. Non usarla per nient'altro.
CurrentAccountAllowPendingReset = Annotated[
    Account,
    Depends(get_current_account),
]