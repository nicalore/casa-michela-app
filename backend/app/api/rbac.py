from collections.abc import Callable
from dataclasses import dataclass
from typing import Annotated, Final

from fastapi import Depends, HTTPException, Request, status

from app.api.current_account import CurrentAccount
from app.core.audit import AUDIT_ACTOR_KEY, AuditActor
from app.services.role_service import RoleService

_FORBIDDEN_ROLE_ERROR: Final[str] = "Non hai i permessi per accedere a questa risorsa"
_FORBIDDEN_PUPIL_ERROR: Final[str] = (
    "Puoi gestire solo le presenze relative a te stesso o ai tuoi figli"
)
_PARENTS_BOOK_ERROR: Final[str] = "Le tue prenotazioni sono gestite dai tuoi genitori"

_ADMIN_ROLE: Final[str] = "ADMIN"
_ACTIVE_ROLE_HEADER: Final[str] = "X-Active-Role"


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

    # An answered-for pupil books, reports and names teachers only if autonomous.
    answered_for: bool = False
    autonomous_bookings: bool = False

    @property
    def is_admin(self) -> bool:
        return _ADMIN_ROLE in self.roles

    # Only an admin wearing the admin hat bypasses closed bands.
    @property
    def overrides_closures(self) -> bool:
        return self.is_admin and self.active_role in (None, _ADMIN_ROLE)

    # Pupils whose bookings are theirs: self as pupil, children as parent; never admins.
    @property
    def own_student_tax_codes(self) -> frozenset[str]:
        own: set[str] = set()

        if "STUDENT" in self.roles:
            own.add(self.tax_code)

        if "PARENT" in self.roles:
            own.update(self.child_tax_codes)

        return frozenset(own)

    @property
    def acts_for_self(self) -> bool:
        return "STUDENT" in self.roles and (
            not self.answered_for or self.autonomous_bookings
        )

    @property
    def bookable_student_tax_codes(self) -> frozenset[str]:
        own: set[str] = set()

        if self.acts_for_self:
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

    # The header's role, not the stored one, which follows the last switch anywhere.
    worn = request.headers.get(_ACTIVE_ROLE_HEADER)

    identity = IdentityContext(
        tax_code=account.tax_code,
        roles=roles,
        child_tax_codes=RoleService.pupil_children_tax_codes(account.person),
        onboarding_completed=account.onboarding_completed_at is not None,
        active_role=RoleService.resolve_active_role(
            roles,
            worn if worn in roles else account.last_active_role,
        ),
        answered_for=RoleService.is_answered_for(account.person),
        autonomous_bookings=account.autonomous_bookings,
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


# Writes only: an answered-for pupil still reads every booking of theirs.
def assert_may_book_for(identity: IdentityContext, student_tax_code: str) -> None:
    if identity.is_admin or student_tax_code in identity.bookable_student_tax_codes:
        return

    themself = "STUDENT" in identity.roles and student_tax_code == identity.tax_code

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=_PARENTS_BOOK_ERROR if themself else _FORBIDDEN_PUPIL_ERROR,
    )
