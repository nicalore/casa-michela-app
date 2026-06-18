from pathlib import Path

from fastapi import (
    APIRouter,
    File,
    HTTPException,
    UploadFile,
    status,
)

from app.api.current_account import CurrentAccount
from app.api.dependencies import DbSession
from app.core.password_policy import PasswordPolicyError
from app.repositories.account_repository import AccountRepository
from app.repositories.identity_repository import IdentityRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
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
)
from app.services.role_service import RoleService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: DbSession) -> LoginResponse:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

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
            detail=f"Account temporarily locked until {err.locked_until}",
        ) from None


@router.post("/refresh", response_model=LoginResponse)
async def refresh(request: RefreshRequest, db: DbSession) -> LoginResponse:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

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
            detail="Invalid refresh token",
        ) from None


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(request: LogoutRequest, db: DbSession) -> None:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

    try:
        await auth_service.logout(request.refresh_token)
    except InvalidRefreshTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        ) from None


@router.get("/me")
async def me(current_account: CurrentAccount, db: DbSession):
    identity_repository = IdentityRepository(db)
    account = await identity_repository.get_account_identity(current_account.tax_code)

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    person = account.person
    roles = RoleService.get_available_roles(person)

    active_role = (
        "ADMIN" if "ADMIN" in roles else (roles[0] if roles else None)
    )

    address_part = f"{person.residence_type} {person.residence_address}".strip()
    
    return {
        "tax_code": account.tax_code,
        "username": account.username,
        "first_name": person.first_name,
        "last_name": person.last_name,
        "full_name": f"{person.first_name} {person.last_name}",
        "profile_image_url": account.profile_image_url,
        "available_roles": roles,
        "active_role": active_role,
        "status": account.status,
        "password_reset_required": account.password_reset_required,
        "gender": person.gender.value if person.gender else None,
        "email": person.email,
        "phone_number": person.phone,
        "birth_date": person.birth_date.isoformat() if person.birth_date else None,
        "birth_city": person.birth_city,
        "birth_province": person.birth_province,
        "address": address_part if (person.residence_type and person.residence_address) else None,
        "address_number": person.residence_street_number,
        "city": person.residence_city,
        "province": person.residence_province,
        "zip_code": person.postal_code,
    }


@router.post("/profile-image")
async def upload_profile_image(
    current_account: CurrentAccount,
    db: DbSession,
    file: UploadFile = File(...),  # noqa: B008
):
    allowed_types = {"image/jpeg", "image/png", "image/webp"}

    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG and WEBP images are allowed",
        )

    if file.filename is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing filename",
        )

    uploads_dir = Path("uploads/profile-images")
    uploads_dir.mkdir(parents=True, exist_ok=True)

    extension = Path(file.filename).suffix.lower()
    filename = f"{current_account.tax_code}{extension}"
    destination = uploads_dir / filename

    content = await file.read()

    with open(destination, "wb") as output:
        output.write(content)
        
    profile_image_url = f"/uploads/profile-images/{filename}"
    current_account.profile_image_url = profile_image_url

    await db.commit()
    return {"profile_image_url": profile_image_url}  


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    request: ChangePasswordRequest,
    current_account: CurrentAccount,
    db: DbSession,
) -> None:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

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


@router.post("/request-password-reset")
async def request_password_reset(
    request: PasswordResetRequest,
    db: DbSession,
) -> dict:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

    await auth_service.request_password_reset(email=request.email)

    return {"message": "If the email exists, a recovery link has been sent."}


@router.post("/reset-password")
async def reset_password(
    request: PasswordResetConfirm,
    db: DbSession,
) -> dict:
    account_repository = AccountRepository(db)
    refresh_token_repository = RefreshTokenRepository(db)
    auth_service = AuthService(account_repository, refresh_token_repository)

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

    return {"message": "Password successfully reset."}