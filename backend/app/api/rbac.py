from collections.abc import Callable
from dataclasses import dataclass
from typing import Annotated, Final

from fastapi import Depends, HTTPException, Request, status

from app.api.current_account import CurrentAccount
from app.core.audit import AUDIT_ACTOR_KEY, AuditActor
from app.services.role_service import RoleService

_FORBIDDEN_ROLE_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"

_ADMIN_ROLE: Final[str] = "ADMIN"


@dataclass(frozen=True)
class IdentityContext:
    tax_code: str
    roles: frozenset[str]
    # The pupils among their children; empty unless "PARENT" is in roles.
    child_tax_codes: frozenset[str]

    # False until the first-access flow is done; a few writes are open only during it.
    onboarding_completed: bool = True

    # Which hat the user is wearing. Presentation only: RBAC reads roles.
    active_role: str | None = None

    @property
    def is_admin(self) -> bool:
        return _ADMIN_ROLE in self.roles

    # Pupils whose bookings are theirs: self as pupil, children as parent; never admins.
    @property
    def own_student_tax_codes(self) -> frozenset[str]:
        own: set[str] = set()

        if "STUDENT" in self.roles:
            own.add(self.tax_code)

        if "PARENT" in self.roles:
            own.update(self.child_tax_codes)

        return frozenset(own)


async def get_current_identity(
    request: Request,
    current_account: CurrentAccount,
) -> IdentityContext:
    account = current_account
    roles = frozenset(RoleService.get_available_roles(account.person))

    identity = IdentityContext(
        tax_code=account.tax_code,
        roles=roles,
        child_tax_codes=RoleService.pupil_children_tax_codes(account.person),
        onboarding_completed=account.onboarding_completed_at is not None,
        active_role=RoleService.resolve_active_role(
            roles,
            account.last_active_role,
        ),
    )

    # The audit middleware runs outside the dependency tree and resolves no identity.
    setattr(
        request.state,
        AUDIT_ACTOR_KEY,
        AuditActor(
            tax_code=identity.tax_code,
            role=identity.active_role or "",
        ),
    )

    return identity


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
