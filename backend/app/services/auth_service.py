import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, Final
from uuid import uuid4
from zoneinfo import ZoneInfo

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
    hash_password_async,
    hash_refresh_token,
    verify_password_async,
)
from app.models.account import Account, AccountStatusEnum
from app.models.refresh_token import RefreshToken, TokenTypeEnum
from app.repositories.account_repository import AccountRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.services.auth_result import AuthResult

resend.api_key = settings.resend_api_key

_LOCAL_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_RESET_TOKEN_TYPE: Final[str] = "reset"
_RESET_TOKEN_LIFETIME: Final[timedelta] = timedelta(hours=1)
_PASSWORD_RESET_MIN_DURATION_SECONDS: Final[float] = 2.0

_INVALID_CREDENTIALS_ERROR: Final[str] = "Nome utente o password non validi"
_ACCOUNT_DISABLED_ERROR: Final[str] = "Account disabilitato"
_ACCOUNT_NOT_FOUND_ERROR: Final[str] = "Account non trovato"
_ACCOUNT_LOCKED_ERROR: Final[str] = "Account bloccato fino al {locked_until}"
_CURRENT_PASSWORD_ERROR: Final[str] = "La password attuale non è corretta"
_PASSWORD_REUSE_ERROR: Final[str] = (
    "La nuova password deve essere diversa da quella attuale"
)
_INVALID_TOKEN_TYPE_ERROR: Final[str] = "Tipo di token non valido"
_INVALID_TOKEN_PAYLOAD_ERROR: Final[str] = "Contenuto del token non valido"
_INVALID_RESET_TOKEN_ERROR: Final[str] = (
    "Token di reimpostazione non valido o scaduto"
)
_EXPIRED_RESET_LINK_ERROR: Final[str] = (
    "Il link di reimpostazione della password non è più valido. "
    "Effettua una nuova richiesta."
)
_EMAIL_SEND_ERROR: Final[str] = "Errore nell'invio dell'email via Resend: {error}"

_EMAIL_SENDER: Final[str] = "Associazione Casa Michela <supporto@app.casamichela.it>"
_EMAIL_REPLY_TO: Final[str] = "nicolo.calore@casamichela.it"
_EMAIL_LOGO_URL: Final[str] = (
    "https://primary.jwwb.nl/public/y/k/w/temp-mfffkbfpkmjgalfrjfhx/"
    "logo-casamichela-1-high-bl0vca.png?enable-io=true&width=100"
)

_EMAIL_TEMPLATE: Final[str] = """
<div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; color: #333333; line-height: 1.6;">
    <div style="text-align: center; margin-bottom: 30px;">
        <img src="{logo_url}" alt="Associazione Casa Michela" style="width: 120px; height: auto;" />
        <p style="margin-top: 10px; color: #003C82; font-weight: bold; font-size: 18px;"> Associazione Casa Michela </p>
    </div>
    <h2 style="color: #003C82;"> {heading} </h2>
    <p>Ciao,</p>
    {body}
    <p>A presto,<br>
    <strong>Associazione Casa Michela</strong></p>
</div>
"""

_ACCOUNT_LOCKED_EMAIL_BODY: Final[str] = """
    <p>Per proteggere il tuo account, abbiamo temporaneamente bloccato l'accesso a seguito di ripetuti tentativi di autenticazione non riusciti.</p>
    <p>Potrai effettuare nuovamente l'accesso a partire dal seguente momento:</p>
    <div style="text-align: center; margin: 30px 0;">
        <strong>{unlock_time}</strong>
    </div>
    <p>Se sei stato tu a effettuare questi tentativi, attendi lo scadere del blocco prima di riprovare ad accedere.</p>
    <p>Se invece ritieni che qualcuno abbia tentato di accedere al tuo account, ti invitiamo a rispondere a questa email o a contattare l'Associazione il prima possibile.</p>
"""

_PASSWORD_CHANGED_EMAIL_BODY: Final[str] = """
    <p>Ti confermiamo che la password del tuo account è stata modificata con successo.</p>
    <p>Se non hai effettuato tu l'operazione, rispondi a questa email o contatta direttamente l'Associazione.</p>
"""

_PASSWORD_RESET_EMAIL_BODY: Final[str] = """
    <p>Hai richiesto di reimpostare la password del tuo account.</p>
    <p>Per procedere, clicca sul pulsante qui sotto:</p>
    <div style="text-align: center; margin: 30px 0;">
        <a href="{reset_link}" style="display: inline-block; padding: 12px 24px; background-color: #003C82; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: bold;"> Reimposta Password </a>
    </div>
    <p>Se il pulsante non funziona, copia e incolla il seguente link nel browser:</p>
    <p style="word-break: break-all;"><a href="{reset_link}">{reset_link}</a></p>
    <p>Per motivi di sicurezza, la richiesta sarà valida per <strong>1 ora</strong>. Trascorso questo tempo, dovrai effettuarne una nuova.</p>
    <p>Se hai bisogno di assistenza o riscontri qualche problema, rispondi a questa email oppure contatta direttamente l'Associazione.</p>
"""


class AuthenticationError(Exception):
    pass


class AccountDisabledError(Exception):
    pass


class InvalidRefreshTokenError(Exception):
    pass


class PasswordReuseError(Exception):
    pass


class AccountLockedError(Exception):
    def __init__(self, locked_until: datetime) -> None:
        self.locked_until = locked_until
        super().__init__(_ACCOUNT_LOCKED_ERROR.format(locked_until=locked_until))


class AuthService:
    def __init__(
        self,
        account_repository: AccountRepository,
        refresh_token_repository: RefreshTokenRepository,
    ) -> None:
        self.account_repository = account_repository
        self.refresh_token_repository = refresh_token_repository

    def _send_email(
        self,
        recipient: str,
        subject: str,
        heading: str,
        body: str,
    ) -> None:
        try:
            resend.Emails.send(
                {
                    "from": _EMAIL_SENDER,
                    "to": recipient,
                    "reply_to": _EMAIL_REPLY_TO,
                    "subject": subject,
                    "html": _EMAIL_TEMPLATE.format(
                        logo_url=_EMAIL_LOGO_URL,
                        heading=heading,
                        body=body,
                    ),
                }
            )
        except Exception as error:
            print(_EMAIL_SEND_ERROR.format(error=error))

    def _send_account_locked_email(
        self,
        account: Account,
        locked_until: datetime,
    ) -> None:
        if not (account.person and account.person.email):
            return

        unlock_time = locked_until.astimezone(_LOCAL_TIMEZONE).strftime(
            "%d/%m/%Y alle ore %H:%M"
        )

        self._send_email(
            recipient=account.person.email,
            subject="Account temporaneamente bloccato - Associazione Casa Michela",
            heading="Account Temporaneamente Bloccato",
            body=_ACCOUNT_LOCKED_EMAIL_BODY.format(unlock_time=unlock_time),
        )

    def _send_password_changed_email(self, account: Account) -> None:
        if not (account.person and account.person.email):
            return

        self._send_email(
            recipient=account.person.email,
            subject="Conferma Modifica Password - Associazione Casa Michela",
            heading="Password Modificata",
            body=_PASSWORD_CHANGED_EMAIL_BODY,
        )

    def _send_password_reset_email(self, account: Account, reset_link: str) -> None:
        self._send_email(
            recipient=account.person.email,
            subject="Recupero Password - Associazione Casa Michela",
            heading="Recupero Password",
            body=_PASSWORD_RESET_EMAIL_BODY.format(reset_link=reset_link),
        )

    async def _create_session(self, account: Account, now: datetime) -> AuthResult:
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
            token_type=TokenTypeEnum.REFRESH,
        )

        await self.refresh_token_repository.save(refresh_token_record)

        return AuthResult(
            access_token=access_token,
            refresh_token=refresh_token,
            password_reset_required=account.password_reset_required,
        )

    async def _load_valid_refresh_token(
        self,
        refresh_token: str,
        now: datetime | None = None,
    ) -> tuple[dict[str, Any], RefreshToken]:
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

        if stored_token.token_type != TokenTypeEnum.REFRESH:
            raise InvalidRefreshTokenError()

        # Expiry is checked only when a reference time is given: logout and
        # password change must keep working with an expired but valid token.
        if now is not None and now >= stored_token.expires_at:
            raise InvalidRefreshTokenError()

        if hash_refresh_token(refresh_token) != stored_token.token_hash:
            raise InvalidRefreshTokenError()

        return payload, stored_token

    async def _load_valid_reset_token(
        self,
        token: str,
        invalid_token_error: str,
    ) -> tuple[str, RefreshToken]:
        try:
            payload = jwt_decode(
                token,
                settings.jwt_access_secret,
                algorithms=[settings.jwt_algorithm],
            )
        except InvalidTokenError as err:
            raise AuthenticationError(invalid_token_error) from err

        if payload.get("type") != _RESET_TOKEN_TYPE:
            raise AuthenticationError(_INVALID_TOKEN_TYPE_ERROR)

        tax_code = payload.get("sub")
        if not isinstance(tax_code, str):
            raise AuthenticationError(_INVALID_TOKEN_PAYLOAD_ERROR)

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise AuthenticationError(_INVALID_TOKEN_PAYLOAD_ERROR)

        stored_token = await self.refresh_token_repository.get_by_token_id(token_id)

        if stored_token is None or stored_token.revoked_at is not None:
            raise AuthenticationError(invalid_token_error)

        if stored_token.token_type != TokenTypeEnum.PASSWORD_RESET:
            raise AuthenticationError(_INVALID_TOKEN_TYPE_ERROR)

        if hash_refresh_token(token) != stored_token.token_hash:
            raise AuthenticationError(invalid_token_error)

        return tax_code, stored_token

    async def authenticate(self, username: str, password: str) -> AuthResult:
        account = await self.account_repository.get_by_username(username)

        if account is None:
            raise AuthenticationError(_INVALID_CREDENTIALS_ERROR)

        now = datetime.now(UTC)

        current_lock = account.locked_until
        if current_lock is not None and now <= current_lock:
            raise AccountLockedError(current_lock)

        if account.last_failed_login_attempt is not None:
            elapsed = now - account.last_failed_login_attempt
            if elapsed >= timedelta(minutes=settings.failed_login_reset_minutes):
                account.failed_login_attempts = 0

        if not await verify_password_async(password, account.password_hash):
            account.failed_login_attempts += 1
            account.last_failed_login_attempt = now

            new_lock: datetime | None = None
            if account.failed_login_attempts >= settings.max_failed_login_attempts:
                new_lock = now + timedelta(minutes=settings.account_lock_minutes)
                account.locked_until = new_lock

            await self.account_repository.save(account)
            await self.account_repository.commit()

            if new_lock is not None:
                self._send_account_locked_email(account, new_lock)
                raise AccountLockedError(new_lock)

            raise AuthenticationError(_INVALID_CREDENTIALS_ERROR)

        if account.status != AccountStatusEnum.ACTIVE:
            raise AccountDisabledError(_ACCOUNT_DISABLED_ERROR)

        account.failed_login_attempts = 0
        account.last_failed_login_attempt = None
        account.locked_until = None
        account.last_login = now

        await self.account_repository.save(account)
        result = await self._create_session(account, now)
        await self.account_repository.commit()

        return result

    async def refresh(self, refresh_token: str) -> AuthResult:
        now = datetime.now(UTC)

        payload, stored_token = await self._load_valid_refresh_token(
            refresh_token,
            now,
        )

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
        _, stored_token = await self._load_valid_refresh_token(refresh_token)

        await self.refresh_token_repository.revoke(stored_token)
        await self.account_repository.commit()

    async def change_password(
        self,
        account: Account,
        current_password: str,
        new_password: str,
        refresh_token: str,
    ) -> None:
        if not await verify_password_async(current_password, account.password_hash):
            raise AuthenticationError(_CURRENT_PASSWORD_ERROR)

        if await verify_password_async(new_password, account.password_hash):
            raise PasswordReuseError(_PASSWORD_REUSE_ERROR)

        validate_password(new_password)

        _, stored_token = await self._load_valid_refresh_token(refresh_token)

        account.password_hash = await hash_password_async(new_password)
        account.password_reset_required = False

        await self.account_repository.save(account)
        await self.refresh_token_repository.revoke_all_for_account_except(
            account_tax_code=account.tax_code,
            token_id=stored_token.token_id,
        )
        await self.account_repository.commit()

        self._send_password_changed_email(account)

    async def request_password_reset(self, username: str) -> None:
        started_at = asyncio.get_running_loop().time()

        try:
            account = await self.account_repository.get_by_username(username)

            if account is None:
                return

            if account.person is None or not account.person.email:
                return

            now = datetime.now(UTC)
            reset_token_id = str(uuid4())

            reset_token = jwt_encode(
                {
                    "sub": account.tax_code,
                    "type": _RESET_TOKEN_TYPE,
                    "jti": reset_token_id,
                    "exp": now + _RESET_TOKEN_LIFETIME,
                },
                settings.jwt_access_secret,
                algorithm=settings.jwt_algorithm,
            )

            reset_token_record = RefreshToken(
                account_tax_code=account.tax_code,
                token_id=reset_token_id,
                token_hash=hash_refresh_token(reset_token),
                expires_at=now + _RESET_TOKEN_LIFETIME,
                token_type=TokenTypeEnum.PASSWORD_RESET,
            )

            await self.refresh_token_repository.save(reset_token_record)
            await self.account_repository.commit()

            reset_link = f"{settings.frontend_url}/reset-password?token={reset_token}"

            self._send_password_reset_email(account, reset_link)

        finally:
            # Constant minimum duration: without it, the response time would
            # reveal whether an account exists for the given username.
            elapsed = asyncio.get_running_loop().time() - started_at
            remaining = _PASSWORD_RESET_MIN_DURATION_SECONDS - elapsed

            if remaining > 0:
                await asyncio.sleep(remaining)

    async def reset_password(self, token: str, new_password: str) -> None:
        tax_code, stored_token = await self._load_valid_reset_token(
            token,
            _EXPIRED_RESET_LINK_ERROR,
        )

        account = await self.account_repository.get_by_tax_code(tax_code)
        if account is None:
            raise AuthenticationError(_ACCOUNT_NOT_FOUND_ERROR)

        validate_password(new_password)

        # The token is consumed before the password is written, so that a
        # failure halfway through cannot leave it usable a second time.
        await self.refresh_token_repository.revoke(stored_token)

        account.password_hash = await hash_password_async(new_password)
        account.password_reset_required = False

        account.failed_login_attempts = 0
        account.locked_until = None

        await self.account_repository.save(account)
        await self.account_repository.commit()

        self._send_password_changed_email(account)

    async def validate_reset_token(self, token: str) -> None:
        await self._load_valid_reset_token(token, _INVALID_RESET_TOKEN_ERROR)