from datetime import UTC, datetime
from typing import Final

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.current_account import CurrentSessionId
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity, IdentityContext, require_role
from app.models.account import Account, AccountStatusEnum
from app.models.person import Person
from app.repositories.account_repository import AccountRepository
from app.repositories.identity_repository import IdentityRepository
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.schemas.auth.session_response import SessionResponse
from app.schemas.person_account import (
    AccountCreate,
    AutonomousBookingsUpdate,
    OpenedAccountResponse,
    PersonAccountResponse,
)
from app.services.account_opening import (
    membership_revoked,
    open_account,
    send_welcome_email,
)
from app.services.auth_service import (
    AccountDisabledError,
    AuthService,
    MissingEmailError,
    SessionNotFoundError,
)
from app.services.role_service import RoleService

router = APIRouter(
    prefix="/people/{tax_code}/account",
    tags=["people"],
    dependencies=[Depends(require_role("ADMIN"))],
)

_ACCOUNT_NOT_FOUND_ERROR: Final[str] = "Account non trovato"
_MISSING_EMAIL_ERROR: Final[str] = "Questa persona non ha un indirizzo email"
_EMAIL_SEND_ERROR: Final[str] = "Impossibile inviare la mail tramite Resend: {error}"
_CURRENT_SESSION_ERROR: Final[str] = "La sessione in uso si chiude con l'uscita"
_SESSION_NOT_FOUND_ERROR: Final[str] = "Sessione non trovata o già disattivata"
_PERSON_NOT_FOUND_ERROR: Final[str] = "Persona non trovata"
_ACCOUNT_EXISTS_ERROR: Final[str] = "Questa persona ha già un account"
_NO_ROLE_ERROR: Final[str] = "Questa persona non può avere un account"
_INVALID_PARENTS_ERROR: Final[str] = "I genitori scelti non sono validi"
_NO_PARENT_ERROR: Final[str] = "Scegli almeno un genitore"
_REVOKED_MEMBERSHIP_ERROR: Final[str] = (
    "L'iscrizione è stata revocata: non è possibile creare l'account"
)
_SUSPENDED_ERROR: Final[str] = "L'account è sospeso"
_OWN_SUSPENSION_ERROR: Final[str] = "Non puoi sospendere il tuo account"
_REVOKED_FOR_GOOD_ERROR: Final[str] = (
    "L'account è sospeso per la revoca dell'iscrizione e non può essere riattivato"
)
_NOT_ANSWERED_FOR_ERROR: Final[str] = (
    "Le prenotazioni autonome valgono solo per uno studente "
    "con responsabilità genitoriali"
)


def _auth_service(db: AsyncSession) -> AuthService:
    return AuthService(AccountRepository(db), RefreshTokenRepository(db))


# Loads the role graph, which tells whether parents answer for the pupil.
async def _account_or_404(service: AuthService, tax_code: str) -> Account:
    repository = IdentityRepository(service.account_repository.session)
    account = await repository.get_account_identity(tax_code.upper())

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_ACCOUNT_NOT_FOUND_ERROR,
        )

    return account


def _own_session(
    account: Account,
    identity: IdentityContext,
    current_session_id: str | None,
) -> str | None:
    return current_session_id if account.tax_code == identity.tax_code else None


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


# An answered-for pupil needs a parent with an account; one is opened if none has.
def _parents_to_open(person: Person, chosen: list[str]) -> list[Person]:
    if not RoleService.is_answered_for(person):
        if chosen:
            raise _bad_request(_INVALID_PARENTS_ERROR)

        return []

    parents = [link.parent.person for link in person.parental_relationships]
    openable = {parent.tax_code for parent in parents if parent.account is None}
    wanted = {code.upper() for code in chosen}

    if not wanted <= openable:
        raise _bad_request(_INVALID_PARENTS_ERROR)

    if not wanted and len(openable) == len(parents):
        raise _bad_request(_NO_PARENT_ERROR)

    return [parent for parent in parents if parent.tax_code in wanted]


# Committed only once every welcome email is out: a lost one would strand its password.
@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=list[OpenedAccountResponse],
)
async def create_person_account(
    tax_code: str,
    payload: AccountCreate,
    db: DbSession,
) -> list[OpenedAccountResponse]:
    person = await IdentityRepository(db).get_person_identity(tax_code.upper())

    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_PERSON_NOT_FOUND_ERROR,
        )

    if person.account is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_ACCOUNT_EXISTS_ERROR,
        )

    # Checked first: a revocation leaves no role either.
    if membership_revoked(person):
        raise _bad_request(_REVOKED_MEMBERSHIP_ERROR)

    if not RoleService.get_available_roles(person):
        raise _bad_request(_NO_ROLE_ERROR)

    parents = _parents_to_open(person, payload.parent_tax_codes)

    opened = [
        await open_account(
            db,
            person,
            autonomous_bookings=(
                payload.autonomous_bookings and RoleService.is_answered_for(person)
            ),
        )
    ]

    for parent in parents:
        opened.append(await open_account(db, parent))

    try:
        for account in opened:
            send_welcome_email(account)
    except Exception as err:
        await db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_EMAIL_SEND_ERROR.format(error=err),
        ) from err

    await db.commit()

    return [
        OpenedAccountResponse(
            tax_code=account.person.tax_code,
            username=account.username,
        )
        for account in opened
    ]


@router.get("", response_model=PersonAccountResponse)
async def get_person_account(
    tax_code: str,
    identity: CurrentIdentity,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> PersonAccountResponse:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)
    own_session = _own_session(account, identity, current_session_id)
    locked = service.is_locked(account, datetime.now(UTC))

    sessions = [
        SessionResponse(
            session_id=session.session_id,
            logged_in_at=session.logged_in_at,
            last_used_at=session.created_at,
            device_type=session.device_type,
            device_name=session.device_name,
            current=session.session_id == own_session,
        )
        for session in await service.list_sessions(account.tax_code)
    ]

    return PersonAccountResponse(
        username=account.username,
        status=account.status,
        lapse=RoleService.access_lapse(account.person),
        answered_for=RoleService.is_answered_for(account.person),
        autonomous_bookings=account.autonomous_bookings,
        last_login=account.last_login,
        password_change_required=account.password_reset_required,
        locked_until=account.locked_until if locked else None,
        failed_login_attempts=account.failed_login_attempts,
        last_failed_login_attempt=account.last_failed_login_attempt,
        sessions=sorted(sessions, key=lambda item: not item.current),
    )


@router.post("/password-change", status_code=status.HTTP_204_NO_CONTENT)
async def force_password_change(tax_code: str, db: DbSession) -> None:
    service = _auth_service(db)

    await service.force_password_change(await _account_or_404(service, tax_code))


@router.post("/password-reset-email", status_code=status.HTTP_204_NO_CONTENT)
async def send_password_reset_email(tax_code: str, db: DbSession) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)

    try:
        await service.send_password_reset(account)
    except AccountDisabledError:
        raise _bad_request(_SUSPENDED_ERROR) from None
    except MissingEmailError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_MISSING_EMAIL_ERROR,
        ) from None
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=_EMAIL_SEND_ERROR.format(error=err),
        ) from err


@router.put("/autonomous-bookings", status_code=status.HTTP_204_NO_CONTENT)
async def set_autonomous_bookings(
    tax_code: str,
    payload: AutonomousBookingsUpdate,
    db: DbSession,
) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)

    if not RoleService.is_answered_for(account.person):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NOT_ANSWERED_FOR_ERROR,
        )

    account.autonomous_bookings = payload.enabled

    await db.commit()


@router.post("/suspension", status_code=status.HTTP_204_NO_CONTENT)
async def suspend_account(
    tax_code: str,
    identity: CurrentIdentity,
    db: DbSession,
) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)

    if account.tax_code == identity.tax_code:
        raise _bad_request(_OWN_SUSPENSION_ERROR)

    if account.status == AccountStatusEnum.ACTIVE:
        await service.suspend(account, AccountStatusEnum.DISABLED)


# Only a suspension by an administrator is lifted; a revocation's stays.
@router.delete("/suspension", status_code=status.HTTP_204_NO_CONTENT)
async def reactivate_account(tax_code: str, db: DbSession) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)

    if account.status == AccountStatusEnum.REVOKED:
        raise _bad_request(_REVOKED_FOR_GOOD_ERROR)

    if account.status == AccountStatusEnum.DISABLED:
        await service.reactivate(account)


@router.delete("/lock", status_code=status.HTTP_204_NO_CONTENT)
async def unlock_account(tax_code: str, db: DbSession) -> None:
    service = _auth_service(db)

    await service.unlock(await _account_or_404(service, tax_code))


# On one's own record the session in use is spared, as in the settings.
@router.delete("/sessions", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_person_sessions(
    tax_code: str,
    identity: CurrentIdentity,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)
    own_session = _own_session(account, identity, current_session_id)

    if own_session is None:
        await service.revoke_all_sessions(account.tax_code)
    else:
        await service.revoke_other_sessions(account.tax_code, own_session)


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_person_session(
    tax_code: str,
    session_id: str,
    identity: CurrentIdentity,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> None:
    service = _auth_service(db)
    account = await _account_or_404(service, tax_code)

    if session_id == _own_session(account, identity, current_session_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_CURRENT_SESSION_ERROR,
        )

    try:
        await service.revoke_session(account.tax_code, session_id)
    except SessionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_SESSION_NOT_FOUND_ERROR,
        ) from None
