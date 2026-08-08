from collections.abc import Callable
from dataclasses import dataclass
from typing import Annotated, Final

from fastapi import Depends, HTTPException, status

from app.api.current_account import CurrentAccount
from app.api.dependencies import DbSession
from app.repositories.identity_repository import IdentityRepository
from app.services.role_service import RoleService

_IDENTITY_NOT_FOUND_ERROR: Final[str] = "Identità non trovata"
_FORBIDDEN_ROLE_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"

_ADMIN_ROLE: Final[str] = "ADMIN"


@dataclass(frozen=True)
class IdentityContext:
    tax_code: str
    roles: frozenset[str]
    # Populated only when "PARENT" is in roles: the tax codes of the
    # students this account is authorized for via parental_responsibilities.
    child_tax_codes: frozenset[str]

    @property
    def is_admin(self) -> bool:
        return _ADMIN_ROLE in self.roles


async def get_current_identity(
    current_account: CurrentAccount,
    db: DbSession,
) -> IdentityContext:
    account = await IdentityRepository(db).get_account_identity(
        current_account.tax_code
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_IDENTITY_NOT_FOUND_ERROR,
        )

    roles = frozenset(RoleService.get_available_roles(account.person))

    child_tax_codes = (
        frozenset(
            relationship.child_tax_code
            for relationship in account.person.parent_profile.children_relationships
        )
        if account.person.parent_profile is not None
        else frozenset()
    )

    return IdentityContext(
        tax_code=account.tax_code,
        roles=roles,
        child_tax_codes=child_tax_codes,
    )


CurrentIdentity = Annotated[IdentityContext, Depends(get_current_identity)]


def require_role(*roles: str) -> Callable[[CurrentIdentity], IdentityContext]:
    allowed = frozenset(roles)

    def _dependency(identity: CurrentIdentity) -> IdentityContext:
        if identity.roles.isdisjoint(allowed):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=_FORBIDDEN_ROLE_ERROR,
            )

        return identity

    return _dependency
