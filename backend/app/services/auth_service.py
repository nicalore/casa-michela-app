from datetime import UTC, datetime, timedelta
from uuid import uuid4

import resend
from jwt import (
    InvalidTokenError,
)
from jwt import (
    decode as jwt_decode,
)
from jwt import (
    encode as jwt_encode,
)

from app.core.config import settings
from app.core.password_policy import validate_password
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.models.account import AccountStatusEnum
from app.models.refresh_token import RefreshToken
from app.repositories.account_repository import AccountRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.services.auth_result import AuthResult

#ConfigureResendAPIKey
resend.api_key = settings.resend_api_key

class AuthenticationError(Exception):
    pass

class AccountDisabledError(Exception):
    pass

class InvalidRefreshTokenError(Exception):
    pass

class AccountLockedError(Exception):
    def __init__(self, locked_until: datetime) -> None:
        self.locked_until = locked_until
        super().__init__(f"Account locked until {locked_until}")

class AuthService:
    def __init__(
        self,
        account_repository: AccountRepository,
        refresh_token_repository: RefreshTokenRepository,
    ) -> None:
        self.account_repository = account_repository
        self.refresh_token_repository = refresh_token_repository

    async def _create_session(self, account, now: datetime) -> AuthResult:
        access_token = create_access_token(
            subject=account.tax_code,
            username=account.username,
        )

        refresh_token_id = str(uuid4())

        refresh_token = create_refresh_token(
            subject=account.tax_code,
            username=account.username,
            token_id=refresh_token_id,
        )

        refresh_token_record = RefreshToken(
            account_tax_code=account.tax_code,
            token_id=refresh_token_id,
            token_hash=hash_refresh_token(refresh_token),
            expires_at=now + timedelta(days=settings.refresh_token_expire_days),
        )

        await self.refresh_token_repository.save(refresh_token_record)

        return AuthResult(
            access_token=access_token,
            refresh_token=refresh_token,
            password_reset_required=account.password_reset_required,
        )

    async def authenticate(self, username: str, password: str) -> AuthResult:
        account = await self.account_repository.get_by_username(username)

        if account is None:
            raise AuthenticationError("Invalid username or password")

        now = datetime.now(UTC)

        if account.locked_until is not None and now <= account.locked_until:
            raise AccountLockedError(account.locked_until)

        if account.last_failed_login_attempt is not None:
            elapsed = now - account.last_failed_login_attempt
            if elapsed >= timedelta(minutes=settings.failed_login_reset_minutes):
                account.failed_login_attempts = 0

        if not verify_password(password, account.password_hash):
            account.failed_login_attempts += 1
            account.last_failed_login_attempt = now

            if account.failed_login_attempts >= settings.max_failed_login_attempts:
                account.locked_until = now + timedelta(minutes=settings.account_lock_minutes)

            await self.account_repository.save(account)
            await self.account_repository.commit()
            
            raise AuthenticationError("Invalid username or password")

        if account.status != AccountStatusEnum.ACTIVE:
            raise AccountDisabledError("Account disabled")

        #ResetFailedLoginCounters
        account.failed_login_attempts = 0
        account.last_failed_login_attempt = None
        account.locked_until = None
        account.last_login = now

        await self.account_repository.save(account)
        result = await self._create_session(account, now)
        await self.account_repository.commit()

        return result
    
    async def refresh(self, refresh_token: str) -> AuthResult:
        try:
            payload = decode_refresh_token(refresh_token)
        except (ValueError, InvalidTokenError) as err:
            raise InvalidRefreshTokenError() from err

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise InvalidRefreshTokenError()

        stored_token = await self.refresh_token_repository.get_by_token_id(token_id)

        if stored_token is None or stored_token.revoked_at is not None:
            raise InvalidRefreshTokenError()

        now = datetime.now(UTC)
        if now >= stored_token.expires_at:
            raise InvalidRefreshTokenError()

        expected_hash = hash_refresh_token(refresh_token)
        if expected_hash != stored_token.token_hash:
            raise InvalidRefreshTokenError()

        #ValidateTypeForTaxCode
        tax_code = payload.get("sub")
        if not isinstance(tax_code, str):
            raise InvalidRefreshTokenError()

        account = await self.account_repository.get_by_tax_code(tax_code)
        if account is None:
            raise InvalidRefreshTokenError()

        await self.refresh_token_repository.revoke(stored_token)
        result = await self._create_session(account, now)
        await self.account_repository.commit()

        return result
    
    async def logout(self, refresh_token: str) -> None:
        try:
            payload = decode_refresh_token(refresh_token)
        except (ValueError, InvalidTokenError) as err:
            raise InvalidRefreshTokenError() from err

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise InvalidRefreshTokenError()

        stored_token = await self.refresh_token_repository.get_by_token_id(token_id)

        if stored_token is None or stored_token.revoked_at is not None:
            raise InvalidRefreshTokenError()

        expected_hash = hash_refresh_token(refresh_token)
        if expected_hash != stored_token.token_hash:
            raise InvalidRefreshTokenError()

        await self.refresh_token_repository.revoke(stored_token)
        await self.account_repository.commit()

    async def change_password(
        self,
        account,
        current_password: str,
        new_password: str,
        refresh_token: str,
    ) -> None:
        if not verify_password(current_password, account.password_hash):
            raise AuthenticationError("Current password is incorrect")

        validate_password(new_password)

        try:
            payload = decode_refresh_token(refresh_token)
        except (ValueError, InvalidTokenError) as err:
            raise InvalidRefreshTokenError() from err

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise InvalidRefreshTokenError()

        stored_token = await self.refresh_token_repository.get_by_token_id(token_id)

        if stored_token is None or stored_token.revoked_at is not None:
            raise InvalidRefreshTokenError()

        expected_hash = hash_refresh_token(refresh_token)
        if expected_hash != stored_token.token_hash:
            raise InvalidRefreshTokenError()

        account.password_hash = hash_password(new_password)
        account.password_reset_required = False

        await self.account_repository.save(account)
        await self.refresh_token_repository.revoke_all_for_account_except(
            account_tax_code=account.tax_code,
            token_id=token_id,
        )
        await self.account_repository.commit()

    async def request_password_reset(self, email: str) -> None:
        account = await self.account_repository.get_by_email(email)

        if account is None:
            return

        expires = timedelta(hours=1)
        reset_token = jwt_encode(
            {
                "sub": account.tax_code,
                "type": "reset",
                "exp": datetime.now(UTC) + expires,
            },
            settings.jwt_access_secret,
            algorithm=settings.jwt_algorithm,
        )

        reset_link = f"{settings.frontend_url}/reset-password?token={reset_token}"

        try:
            resend.Emails.send({
               "from": "Associazione Casa Michela <supporto@app.casamichela.it>", 
               "to": email, "reply_to": "nicolo.calore@casamichela.it", 
               "subject": "Recupero Password - Associazione Casa Michela", 
               "html": f""" <div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; color: #333333; line-height: 1.6;"> 
               <div style="text-align: center; margin-bottom: 30px;"> 
               <img src="https://primary.jwwb.nl/public/y/k/w/temp-mfffkbfpkmjgalfrjfhx/logo-casamichela-1-high-bl0vca.png?enable-io=true&width=100" alt="Associazione Casa Michela" style="width: 120px; height: auto;" /> 
               <p style="margin-top: 10px; color: #003C82; font-weight: bold; font-size: 18px;"> Associazione Casa Michela </p> </div> <h2 style="color: #003C82;"> Recupero Password </h2><p>
               Ciao, </p> 
               <p> Hai richiesto di reimpostare la password del tuo account. </p> 
               <p> Per procedere, clicca sul pulsante qui sotto: </p>
               <div style="text-align: center; margin: 30px 0;"> <a href="{reset_link}" style=" display: inline-block; padding: 12px 24px; background-color: #003C82; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: bold; " > Reimposta Password </a> </div> 
               <p> Se il pulsante non funziona, copia e incolla il seguente link nel browser: </p> 
               <p style="word-break: break-all;"> <a href="{reset_link}"> {reset_link} </a> </p>
               <p> Per motivi di sicurezza, la richiesta sarà valida per <strong>1 ora</strong>. Trascorso questo tempo, dovrai effettuarne una nuova. </p>
               <p> Se hai bisogno di assistenza o riscontri qualche problema, rispondi a questa email oppure contatta direttamente l'Associazione. </p>
               <p> A presto,<br> 
               <strong>Associazione Casa Michela</strong> </p> </div>
               """
            })
        except Exception as e:
            #LogErrorSilently
            print(f"Error sending email via Resend: {e}")

    async def reset_password(self, token: str, new_password: str) -> None:
        try:
            payload = jwt_decode(
                token,
                settings.jwt_access_secret,
                algorithms=[settings.jwt_algorithm],
            )
        except InvalidTokenError as err:
            raise AuthenticationError("Invalid or expired reset token") from err

        if payload.get("type") != "reset":
            raise AuthenticationError("Invalid token type")

        #ValidateTypeForTaxCode
        tax_code = payload.get("sub")
        if not isinstance(tax_code, str):
            raise AuthenticationError("Invalid token payload")

        account = await self.account_repository.get_by_tax_code(tax_code)

        if account is None:
            raise AuthenticationError("Account not found")

        validate_password(new_password)

        account.password_hash = hash_password(new_password)
        account.password_reset_required = False
        
        #ResetSecurityCounters
        account.failed_login_attempts = 0
        account.locked_until = None

        await self.account_repository.save(account)
        await self.account_repository.commit()