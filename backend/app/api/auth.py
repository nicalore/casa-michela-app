from fastapi import (
    APIRouter,
    HTTPException,
    status,
)

from app.api.current_account import (
    CurrentAccount,
)
from app.api.dependencies import DbSession
from app.core.password_policy import (
    PasswordPolicyError,
)
from app.repositories.account_repository import (
    AccountRepository,
)
from app.repositories.refresh_token_repository import (
    RefreshTokenRepository,
)
from app.schemas.auth.change_password_request import (
    ChangePasswordRequest,
)
from app.schemas.auth.login_request import (
    LoginRequest,
)
from app.schemas.auth.login_response import (
    LoginResponse,
)
from app.schemas.auth.logout_request import (
    LogoutRequest,
)
from app.schemas.auth.refresh_request import (
    RefreshRequest,
)
from app.services.auth_service import (
    AccountDisabledError,
    AccountLockedError,
    AuthenticationError,
    AuthService,
    InvalidRefreshTokenError,
)

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


@router.post(
    "/login",
    response_model=LoginResponse,
)
async def login(
    request: LoginRequest,
    db: DbSession,
) -> LoginResponse:
    repository = AccountRepository(
        db,
    )

    refresh_token_repository = (
        RefreshTokenRepository(
            db,
        )
    )

    auth_service = AuthService(
        repository,
        refresh_token_repository,
    )

    try:
        result = await auth_service.authenticate(
            username=request.username,
            password=request.password,
        )

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=(
                result.password_reset_required
            ),
        )

    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        ) from None

    except AccountDisabledError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account disabled",
        ) from None

    except AccountLockedError as err:
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=(
                "Account temporarily locked "
                f"until {err.locked_until}"
            ),
        ) from None
    
@router.post(
    "/refresh",
    response_model=LoginResponse,
)
async def refresh(
    request: RefreshRequest,
    db: DbSession,
) -> LoginResponse:
    account_repository = (
        AccountRepository(db)
    )

    refresh_token_repository = (
        RefreshTokenRepository(db)
    )

    auth_service = AuthService(
        account_repository,
        refresh_token_repository,
    )

    try:
        result = await auth_service.refresh(
            request.refresh_token
        )

        return LoginResponse(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            token_type="bearer",
            password_reset_required=(
                result.password_reset_required
            ),
        )

    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        ) from None

@router.post(
"/logout",
status_code=status.HTTP_204_NO_CONTENT,
)
async def logout(
    request: LogoutRequest,
    db: DbSession,
) -> None:
    account_repository = (
        AccountRepository(db)
    )

    refresh_token_repository = (
        RefreshTokenRepository(db)
    )

    auth_service = AuthService(
        account_repository,
        refresh_token_repository,
    )

    try:
        await auth_service.logout(
            request.refresh_token
        )

    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        ) from None
    
@router.get("/me")
async def me(
    current_account: CurrentAccount,
):
    return {
        "tax_code": (
            current_account.tax_code
        ),
        "username": (
            current_account.username
        ),
        "status": (
            current_account.status
        ),
        "password_reset_required": (
            current_account.password_reset_required
        ),
    }

@router.post(
    "/change-password",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def change_password(
    request: ChangePasswordRequest,
    current_account: CurrentAccount,
    db: DbSession,
) -> None:
    account_repository = (
        AccountRepository(db)
    )

    refresh_token_repository = (
        RefreshTokenRepository(db)
    )

    auth_service = AuthService(
        account_repository,
        refresh_token_repository,
    )

    try:
        await auth_service.change_password(
            account=current_account,
            current_password=(
                request.current_password
            ),
            new_password=(
                request.new_password
            ),
            refresh_token=(
                request.refresh_token
            ),
        )

    except AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        ) from None

    except PasswordPolicyError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from None

    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        ) from None