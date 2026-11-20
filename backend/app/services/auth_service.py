import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, Final, TypedDict
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
from app.core.i18n import tr_for
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
from app.models.person import GenderEnum
from app.models.refresh_token import DeviceTypeEnum, RefreshToken, TokenTypeEnum
from app.repositories.account_repository import AccountRepository
from app.repositories.identity_repository import IdentityRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.services import email_service
from app.services.auth_result import AuthResult
from app.services.bilingual import Bilingual
from app.services.role_service import RoleService

_LOCAL_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_RESET_TOKEN_TYPE: Final[str] = "reset"
_RESET_TOKEN_LIFETIME: Final[timedelta] = timedelta(hours=1)
# A forced password change must follow its sign-in within this window.
_PENDING_CHANGE_WINDOW: Final[timedelta] = timedelta(minutes=15)
_PASSWORD_RESET_MIN_DURATION_SECONDS: Final[float] = 2.0

_INVALID_CREDENTIALS_ERROR: Final[Bilingual] = Bilingual(
    "Nome utente o password non validi",
    "Invalid username or password",
)
_ACCOUNT_DISABLED_ERROR: Final[Bilingual] = Bilingual(
    "Account disabilitato",
    "Account disabled",
)
_ACCOUNT_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Account non trovato",
    "Account not found",
)
_ACCOUNT_LOCKED_ERROR: Final[Bilingual] = Bilingual(
    "Account bloccato fino al {locked_until}",
    "Account locked until {locked_until}",
)
_CURRENT_PASSWORD_ERROR: Final[Bilingual] = Bilingual(
    "La password attuale non è corretta",
    "The current password is not correct",
)
_PASSWORD_REUSE_ERROR: Final[Bilingual] = Bilingual(
    "La nuova password deve essere diversa da quella attuale",
    "The new password must be different from the current one",
)
_INVALID_TOKEN_TYPE_ERROR: Final[Bilingual] = Bilingual(
    "Tipo di token non valido",
    "Invalid token type",
)
_INVALID_TOKEN_PAYLOAD_ERROR: Final[Bilingual] = Bilingual(
    "Contenuto del token non valido",
    "Invalid token content",
)
_INVALID_RESET_TOKEN_ERROR: Final[Bilingual] = Bilingual(
    "Token di reimpostazione non valido o scaduto",
    "Invalid or expired reset token",
)
_EXPIRED_RESET_LINK_ERROR: Final[Bilingual] = Bilingual(
    "Il link di reimpostazione della password non è più valido. Effettua una nuova "
    "richiesta.",
    "The password reset link is no longer valid. Please make a new request.",
)
_EMAIL_SEND_ERROR: Final[str] = "Errore nell'invio dell'email via Resend: {error}"

_ACCOUNT_LOCKED_EMAIL_BODY: Final[str] = """
    <p>Per proteggere il tuo account, abbiamo temporaneamente bloccato l'accesso a seguito di ripetuti tentativi di autenticazione non riusciti.</p>
    <p>Potrai effettuare nuovamente l'accesso a partire dal seguente momento:</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px; text-align: center;">
        <strong style="color: {ink}; font-size: 17px;">{unlock_time}</strong>
    </div>
    <p>Se sei {been} tu a effettuare questi tentativi, attendi lo scadere del blocco prima di riprovare ad accedere.</p>
    <p>Se invece ritieni che qualcuno abbia tentato di accedere al tuo account, ti invitiamo a rispondere a questa email o a contattare l'Associazione il prima possibile.</p>
"""

_BEEN: Final[dict[GenderEnum, str]] = {
    GenderEnum.M: "stato",
    GenderEnum.F: "stata",
}

_ENGLISH_ACCOUNT_LOCKED_EMAIL_BODY: Final[str] = """
    <p>To protect your account, we have temporarily blocked sign-in after repeated failed sign-in attempts.</p>
    <p>You can sign in again from this moment:</p>
    <div style="margin: 24px 0; padding: 18px 20px; background-color: {paper};
                border: 1px solid {line}; border-radius: 18px; text-align: center;">
        <strong style="color: {ink}; font-size: 17px;">{unlock_time}</strong>
    </div>
    <p>If you made these attempts yourself, wait until the block ends before trying to sign in again.</p>
    <p>If instead you think someone tried to get into your account, please reply to this email or contact the Association as soon as possible.</p>
"""

_PASSWORD_CHANGED_EMAIL_BODY: Final[Bilingual] = Bilingual(
    """
    <p>Ti confermiamo che la password del tuo account è stata modificata con successo.</p>
    <p>Se non hai effettuato tu l'operazione, rispondi a questa email o contatta direttamente l'Associazione.</p>
""",
    """
    <p>We confirm that your account's password has been changed successfully.</p>
    <p>If you did not make this change, reply to this email or contact the Association directly.</p>
""",
)

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

_ENGLISH_PASSWORD_RESET_EMAIL_BODY: Final[str] = """
    <p>You asked to reset your account's password.</p>
    <p>To go ahead, click the button below:</p>
    <div style="text-align: center; margin: 28px 0;">
        <a href="{reset_link}"
           style="display: inline-block; padding: 15px 30px; background-color: {teal};
                  color: #ffffff; text-decoration: none; border-radius: 26px;
                  font-weight: 700; font-size: 14px; letter-spacing: 0.6px;
                  text-transform: uppercase;"> Reset password </a>
    </div>
    <p>If the button doesn't work, copy and paste this link into your browser:</p>
    <p style="word-break: break-all;">
        <a href="{reset_link}" style="color: {teal};">{reset_link}</a>
    </p>
    <p>For security reasons, the request will be valid for <strong>1 hour</strong>. After that, you will need to make a new one.</p>
    <p>If you need help or run into any problem, reply to this email or contact the Association directly.</p>
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


class PasswordChangeExpiredError(Exception):
    pass


class MissingEmailError(Exception):
    pass


class AccountLockedError(Exception):
    def __init__(self, locked_until: datetime) -> None:
        self.locked_until = locked_until
        super().__init__(
            _ACCOUNT_LOCKED_ERROR.for_request().format(locked_until=locked_until)
        )


class _ResetEmail(TypedDict):
    recipient: str
    subject: str
    heading: str
    body: str
    language: str | None


class AuthService:
    def __init__(
        self,
        account_repository: AccountRepository,
        refresh_token_repository: RefreshTokenRepository,
    ) -> None:
        self.account_repository = account_repository
        self.refresh_token_repository = refresh_token_repository

    # False when suspended, revoked, or with no enrollment behind it.
    async def _usable(self, account: Account) -> bool:
        if account.status != AccountStatusEnum.ACTIVE:
            return False

        repository = IdentityRepository(self.account_repository.session)
        identity = await repository.get_account_identity(account.tax_code)

        if identity is None:
            return False

        return RoleService.access_lapse(identity.person) is None

    # A lost notice must not fail the sign-in it accompanies.
    def _send_email(
        self,
        recipient: str,
        subject: str,
        heading: str,
        body: str,
        language: str | None = None,
    ) -> None:
        try:
            email_service.send_email(
                recipient=recipient,
                subject=subject,
                heading=heading,
                body=body,
                language=language,
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

        # Written to the account's owner, in their language.
        language = account.language
        unlock_time = locked_until.astimezone(_LOCAL_TIMEZONE).strftime(
            tr_for(language, "%d/%m/%Y alle ore %H:%M", "%d/%m/%Y at %H:%M")
        )
        body = tr_for(
            language,
            _ACCOUNT_LOCKED_EMAIL_BODY,
            _ENGLISH_ACCOUNT_LOCKED_EMAIL_BODY,
        )

        self._send_email(
            recipient=account.person.email,
            subject=tr_for(
                language,
                "Account temporaneamente bloccato - Associazione Casa Michela",
                "Account temporarily locked - Associazione Casa Michela",
            ),
            heading=tr_for(
                language,
                "Account temporaneamente bloccato",
                "Account temporarily locked",
            ),
            body=body.format(
                unlock_time=unlock_time,
                been=_BEEN[account.person.gender],
                paper=email_service.PAPER,
                line=email_service.LINE,
                ink=email_service.INK,
            ),
            language=language,
        )

    def _send_password_changed_email(self, account: Account) -> None:
        if not (account.person and account.person.email):
            return

        language = account.language

        self._send_email(
            recipient=account.person.email,
            subject=tr_for(
                language,
                "Conferma modifica password - Associazione Casa Michela",
                "Password change confirmed - Associazione Casa Michela",
            ),
            heading=tr_for(language, "Password modificata", "Password changed"),
            body=_PASSWORD_CHANGED_EMAIL_BODY.to(language),
            language=language,
        )

    def _password_reset_email(
        self,
        account: Account,
        reset_link: str,
    ) -> _ResetEmail:
        language = account.language
        body = tr_for(
            language,
            _PASSWORD_RESET_EMAIL_BODY,
            _ENGLISH_PASSWORD_RESET_EMAIL_BODY,
        )

        return {
            "recipient": account.person.email,
            "subject": tr_for(
                language,
                "Recupero password - Associazione Casa Michela",
                "Password recovery - Associazione Casa Michela",
            ),
            "heading": tr_for(language, "Recupero password", "Password recovery"),
            "body": body.format(reset_link=reset_link, teal=email_service.TEAL),
            "language": language,
        }

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
            account_tax_code=account.tax_code,
            session_id=session_id,
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

    # A just-replaced token is honoured briefly, unless its session has ended.
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
            raise AuthenticationError(_INVALID_TOKEN_TYPE_ERROR.for_request())

        tax_code = payload.get("sub")
        if not isinstance(tax_code, str):
            raise AuthenticationError(_INVALID_TOKEN_PAYLOAD_ERROR.for_request())

        token_id = payload.get("jti")
        if not isinstance(token_id, str):
            raise AuthenticationError(_INVALID_TOKEN_PAYLOAD_ERROR.for_request())

        stored_token = await self.refresh_token_repository.get_by_token_id(token_id)

        if stored_token is None or stored_token.revoked_at is not None:
            raise AuthenticationError(invalid_token_error)

        if stored_token.token_type != TokenTypeEnum.PASSWORD_RESET:
            raise AuthenticationError(_INVALID_TOKEN_TYPE_ERROR.for_request())

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
            raise AuthenticationError(_INVALID_CREDENTIALS_ERROR.for_request())

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

            # A lockout ends every session too: a guesser keeps no foothold.
            if new_lock is not None:
                await self.refresh_token_repository.revoke_all_for_account(
                    account.tax_code
                )

            await self.account_repository.commit()

            if new_lock is not None:
                self._send_account_locked_email(account, new_lock)
                raise AccountLockedError(new_lock)

            raise AuthenticationError(_INVALID_CREDENTIALS_ERROR.for_request())

        if not await self._usable(account):
            raise AccountDisabledError(_ACCOUNT_DISABLED_ERROR.for_request())

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

        # A lapse is first met here: its sessions end, as a suspension's do.
        if not await self._usable(account):
            await self.refresh_token_repository.revoke_all_for_account(tax_code)
            await self.account_repository.commit()

            raise InvalidRefreshTokenError()

        if self._pending_change_expired(account, stored_token, now):
            raise PasswordChangeExpiredError()

        # Whole session revoked: on a replay the live token is the unseen successor.
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

    @staticmethod
    def _pending_change_expired(
        account: Account,
        stored_token: RefreshToken,
        now: datetime,
    ) -> bool:
        return (
            account.password_reset_required
            and now - stored_token.logged_in_at > _PENDING_CHANGE_WINDOW
        )

    # Fixed at sign-in; sessions predating devices take the first one seen.
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

    async def revoke_other_sessions(
        self,
        account_tax_code: str,
        session_id: str,
    ) -> None:
        await self.refresh_token_repository.revoke_sessions_except(
            account_tax_code,
            session_id,
        )

        await self.account_repository.commit()

    async def revoke_all_sessions(self, account_tax_code: str) -> None:
        await self.refresh_token_repository.revoke_all_for_account(account_tax_code)
        await self.account_repository.commit()

    async def logout(self, refresh_token: str) -> None:
        _, stored_token = await self._load_valid_refresh_token(refresh_token)

        await self.refresh_token_repository.revoke(stored_token)
        await self.account_repository.commit()

    async def change_password(
        self,
        account: Account,
        current_password: str | None,
        new_password: str,
        refresh_token: str,
    ) -> None:
        _, stored_token = await self._load_valid_refresh_token(refresh_token)

        # Its sign-in time stands for the current password below.
        if stored_token.account_tax_code != account.tax_code:
            raise InvalidRefreshTokenError()

        if current_password is None:
            # Typed at the sign-in a moment ago: only the forced change skips it.
            if not account.password_reset_required:
                raise AuthenticationError(_CURRENT_PASSWORD_ERROR.for_request())

            if self._pending_change_expired(account, stored_token, datetime.now(UTC)):
                raise PasswordChangeExpiredError()

        elif not await verify_password_async(current_password, account.password_hash):
            raise AuthenticationError(_CURRENT_PASSWORD_ERROR.for_request())

        if await verify_password_async(new_password, account.password_hash):
            raise PasswordReuseError(_PASSWORD_REUSE_ERROR.for_request())

        validate_password(new_password)

        account.password_hash = await hash_password_async(new_password)
        account.password_reset_required = False

        await self.account_repository.save(account)
        await self.refresh_token_repository.revoke_all_for_account_except(
            account_tax_code=account.tax_code,
            token_id=stored_token.token_id,
        )
        await self.account_repository.commit()

        self._send_password_changed_email(account)

    async def _issue_reset_link(self, account: Account) -> str:
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

        # After '#': browsers never send the fragment, so no server logs the token.
        return f"{settings.frontend_url}/reset-password#token={reset_token}"

    async def request_password_reset(self, username: str) -> None:
        started_at = asyncio.get_running_loop().time()

        try:
            account = await self.account_repository.get_by_username(username)

            if account is None or not await self._usable(account):
                return

            if account.person is None or not account.person.email:
                return

            reset_link = await self._issue_reset_link(account)

            self._send_email(**self._password_reset_email(account, reset_link))

        finally:
            # Constant minimum duration, or timing would reveal account existence.
            elapsed = asyncio.get_running_loop().time() - started_at
            remaining = _PASSWORD_RESET_MIN_DURATION_SECONDS - elapsed

            if remaining > 0:
                await asyncio.sleep(remaining)

    # Sent on an administrator's behalf, so a failed delivery is raised, not swallowed.
    async def send_password_reset(self, account: Account) -> None:
        if not await self._usable(account):
            raise AccountDisabledError(_ACCOUNT_DISABLED_ERROR.for_request())

        if account.person is None or not account.person.email:
            raise MissingEmailError()

        reset_link = await self._issue_reset_link(account)

        email_service.send_email(**self._password_reset_email(account, reset_link))

    async def force_password_change(self, account: Account) -> None:
        account.password_reset_required = True

        await self.account_repository.save(account)
        await self.refresh_token_repository.revoke_all_for_account(account.tax_code)
        await self.account_repository.commit()

    async def suspend(self, account: Account, status: AccountStatusEnum) -> None:
        account.status = status

        await self.account_repository.save(account)
        await self.refresh_token_repository.revoke_all_for_account(account.tax_code)
        await self.account_repository.commit()

    async def reactivate(self, account: Account) -> None:
        account.status = AccountStatusEnum.ACTIVE

        await self.account_repository.save(account)
        await self.account_repository.commit()

    async def unlock(self, account: Account) -> None:
        account.failed_login_attempts = 0
        account.last_failed_login_attempt = None
        account.locked_until = None

        await self.account_repository.save(account)
        await self.account_repository.commit()

    # Same bound as the sign-in, which refuses up to the lock's last instant.
    @staticmethod
    def is_locked(account: Account, now: datetime) -> bool:
        return account.locked_until is not None and now <= account.locked_until

    async def reset_password(self, token: str, new_password: str) -> None:
        tax_code, stored_token = await self._load_valid_reset_token(
            token,
            _EXPIRED_RESET_LINK_ERROR.for_request(),
        )

        account = await self.account_repository.get_by_tax_code(tax_code)
        if account is None:
            raise AuthenticationError(_ACCOUNT_NOT_FOUND_ERROR.for_request())

        if not await self._usable(account):
            raise AuthenticationError(_ACCOUNT_DISABLED_ERROR.for_request())

        validate_password(new_password)

        # Token consumed before the write so a failure cannot leave it reusable.
        await self.refresh_token_repository.revoke(stored_token)

        # Whoever reset it may be locking out somebody else: every session ends.
        await self.refresh_token_repository.revoke_all_for_account(account.tax_code)

        account.password_hash = await hash_password_async(new_password)
        account.password_reset_required = False

        account.failed_login_attempts = 0
        account.locked_until = None

        await self.account_repository.save(account)
        await self.account_repository.commit()

        self._send_password_changed_email(account)

    async def validate_reset_token(self, token: str) -> None:
        await self._load_valid_reset_token(
            token,
            _INVALID_RESET_TOKEN_ERROR.for_request(),
        )