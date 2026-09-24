import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, Final
from uuid import uuid4
from zoneinfo import ZoneInfo

from jwt import (
    InvalidTokenError,
)
from jwt import (
    decode as jwt_decode,
)
from jwt import (
    encode as jwt_encode,
)

from app.core.client_device import UNKNOWN_DEVICE, ClientDevice
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
from app.models.refresh_token import DeviceTypeEnum, RefreshToken, TokenTypeEnum
from app.repositories.account_repository import AccountRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.services import email_service
from app.services.auth_result import AuthResult

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

_ACCOUNT_LOCKED_EMAIL_BODY: Final[str] = """
    <p>Per proteggere il tuo account, abbiamo temporaneamente bloccato l'accesso a seguito di ripetuti tentativi di autenticazione non riusciti.</p>
    <p>Potrai effettuare nuovamente l'accesso a partire dal seguente momento:</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px; text-align: center;">
        <strong style="color: {ink}; font-size: 17px;">{unlock_time}</strong>
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
    <div style="text-align: center; margin: 28px 0;">
        <a href="{reset_link}"
           style="display: inline-block; padding: 15px 30px; background-color: {teal};
                  color: #ffffff; text-decoration: none; border-radius: 26px;
                  font-weight: 700; font-size: 14px; letter-spacing: 0.6px;
                  text-transform: uppercase;"> Reimposta password </a>
    </div>
    <p>Se il pulsante non funziona, copia e incolla il seguente link nel browser:</p>
    <p style="word-break: break-all;">
        <a href="{reset_link}" style="color: {teal};">{reset_link}</a>
    </p>
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


class SessionNotFoundError(Exception):
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

    # A lost notice must not fail the sign-in it accompanies.
    def _send_email(
        self,
        recipient: str,
        subject: str,
        heading: str,
        body: str,
    ) -> None:
        try:
            email_service.send_email(
                recipient=recipient,
                subject=subject,
                heading=heading,
                body=body,
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
            heading="Account temporaneamente bloccato",
            body=_ACCOUNT_LOCKED_EMAIL_BODY.format(
                unlock_time=unlock_time,
                paper=email_service.PAPER,
                line=email_service.LINE,
                ink=email_service.INK,
            ),
        )

    def _send_password_changed_email(self, account: Account) -> None:
        if not (account.person and account.person.email):
            return

        self._send_email(
            recipient=account.person.email,
            subject="Conferma modifica password - Associazione Casa Michela",
            heading="Password modificata",
            body=_PASSWORD_CHANGED_EMAIL_BODY,
        )

    def _send_password_reset_email(self, account: Account, reset_link: str) -> None:
        self._send_email(
            recipient=account.person.email,
            subject="Recupero password - Associazione Casa Michela",
            heading="Recupero password",
            body=_PASSWORD_RESET_EMAIL_BODY.format(
                reset_link=reset_link,
                teal=email_service.TEAL,
            ),
        )

    async def _create_session(
        self,
        account: Account,
        now: datetime,
        session_id: str,
        logged_in_at: datetime,
        device: ClientDevice,
    ) -> AuthResult:
        access_token = create_access_token(
            subject=account.tax_code,
            username=account.username,
            session_id=session_id,
        )

        refresh_token_id = str(uuid4())

        refresh_token = create_refresh_token(
            subject=account.tax_code,
            username=account.username,
            token_id=refresh_token_id,
            session_id=session_id,
        )

        refresh_token_record = RefreshToken(
            account_tax_code=account.tax_code,
            token_id=refresh_token_id,
            token_hash=hash_refresh_token(refresh_token),
            expires_at=now + timedelta(days=settings.refresh_token_expire_days),
            token_type=TokenTypeEnum.REFRESH,
            session_id=session_id,
            logged_in_at=logged_in_at,
            device_type=device.device_type,
            device_name=device.name,
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
        rotating: bool = False,
    ) -> tuple[dict[str, Any], RefreshToken]:
        try:
            payload = decode_refresh_token(refresh_token)
        except (ValueError, InvalidTokenError) as err:
            raise InvalidRefreshTokenError() from err

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise InvalidRefreshTokenError()

        stored_token = await self.refresh_token_repository.get_by_token_id(
            token_id,
            for_update=rotating,
        )

        if stored_token is None:
            raise InvalidRefreshTokenError()

        if stored_token.revoked_at is not None and not (
            rotating and await self._replaced_moments_ago(stored_token)
        ):
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

    # A client that never got the answer to a rotation still holds the token
    # it replaced: honoured for a short while, unless the session has ended.
    async def _replaced_moments_ago(self, stored_token: RefreshToken) -> bool:
        now = datetime.now(UTC)
        grace = timedelta(seconds=settings.refresh_token_grace_seconds)

        if stored_token.revoked_at is None or now - stored_token.revoked_at > grace:
            return False

        return await self.refresh_token_repository.session_is_live(
            stored_token.account_tax_code,
            stored_token.session_id,
            now,
        )

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

    async def authenticate(
        self,
        username: str,
        password: str,
        device: ClientDevice = UNKNOWN_DEVICE,
    ) -> AuthResult:
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

            # Whoever is guessing must not keep a foothold: a lockout ends
            # every session too.
            if new_lock is not None:
                await self.refresh_token_repository.revoke_all_for_account(
                    account.tax_code
                )

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
        result = await self._create_session(
            account,
            now,
            session_id=str(uuid4()),
            logged_in_at=now,
            device=device,
        )
        await self.account_repository.commit()

        return result

    async def refresh(
        self,
        refresh_token: str,
        device: ClientDevice = UNKNOWN_DEVICE,
    ) -> AuthResult:
        now = datetime.now(UTC)

        payload, stored_token = await self._load_valid_refresh_token(
            refresh_token,
            now,
            rotating=True,
        )

        tax_code = payload.get("sub")
        if not isinstance(tax_code, str):
            raise InvalidRefreshTokenError()

        account = await self.account_repository.get_by_tax_code(tax_code)
        if account is None:
            raise InvalidRefreshTokenError()

        # The whole session, not the token alone: on a replay the live one is
        # the successor the client never received.
        await self.refresh_token_repository.revoke_session(
            stored_token.account_tax_code,
            stored_token.session_id,
        )
        result = await self._create_session(
            account,
            now,
            session_id=stored_token.session_id,
            logged_in_at=stored_token.logged_in_at,
            device=self._session_device(stored_token, device),
        )
        await self.account_repository.commit()

        return result

    # Read once, at sign-in; a session from before devices were recorded takes
    # the first description it is given.
    @staticmethod
    def _session_device(
        stored_token: RefreshToken,
        device: ClientDevice,
    ) -> ClientDevice:
        if stored_token.device_type != DeviceTypeEnum.UNKNOWN:
            return ClientDevice(stored_token.device_type, stored_token.device_name)

        return device

    async def list_sessions(self, account_tax_code: str) -> list[RefreshToken]:
        return await self.refresh_token_repository.get_active_sessions(
            account_tax_code,
            datetime.now(UTC),
        )

    async def revoke_session(self, account_tax_code: str, session_id: str) -> None:
        revoked = await self.refresh_token_repository.revoke_session(
            account_tax_code,
            session_id,
        )

        if revoked == 0:
            raise SessionNotFoundError()

        await self.account_repository.commit()

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

            # Not a session: the two columns are filled to satisfy the table.
            reset_token_record = RefreshToken(
                account_tax_code=account.tax_code,
                token_id=reset_token_id,
                token_hash=hash_refresh_token(reset_token),
                expires_at=now + _RESET_TOKEN_LIFETIME,
                token_type=TokenTypeEnum.PASSWORD_RESET,
                session_id=reset_token_id,
                logged_in_at=now,
            )

            await self.refresh_token_repository.save(reset_token_record)
            await self.account_repository.commit()

            reset_link = f"{settings.frontend_url}/reset-password?token={reset_token}"

            self._send_password_reset_email(account, reset_link)

        finally:
            # Constant minimum duration, or timing would reveal account existence.
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

        # Token consumed before the write so a failure cannot leave it reusable.
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