from collections.abc import Callable
from dataclasses import dataclass
from typing import Annotated, Final

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.current_account import CurrentAccount
from app.core.audit import AUDIT_ACTOR_KEY, AuditActor
from app.core.i18n import tr
from app.core.person_refs import KEPT_TAX_CODES_STATE_KEY, keep_for_reader
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import GenderEnum, Person
from app.services.role_service import RoleService

_FORBIDDEN_ROLE_ERROR: Final[tuple[str, str]] = (
    "Non hai i permessi per accedere a questa risorsa",
    "You don't have permission to access this resource",
)
_FORBIDDEN_PUPIL_ERROR: Final[tuple[str, str]] = (
    "Puoi gestire solo le tue presenze o quelle dei tuoi figli",
    "You can only manage your own attendance or your children's",
)
_PARENTS_BOOK_ERROR: Final[tuple[str, str]] = (
    "Le tue prenotazioni sono gestite dai tuoi genitori",
    "Your bookings are managed by your parents",
)
_PARENT_BOOKS_ERRORS: Final[dict[GenderEnum, tuple[str, str]]] = {
    GenderEnum.M: (
        "Le tue prenotazioni sono gestite da tuo padre",
        "Your bookings are managed by your father",
    ),
    GenderEnum.F: (
        "Le tue prenotazioni sono gestite da tua madre",
        "Your bookings are managed by your mother",
    ),
}

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

    # Under another hat an admin reads lessons and hours as that role does.
    @property
    def reads_everything(self) -> bool:
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


# The role this client shows; the stored one follows the last switch on any device.
def worn_role(request: Request) -> str | None:
    return request.headers.get(_ACTIVE_ROLE_HEADER)


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
            worn_role(request),
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


# Apart from the reader's own and children's, tax codes leave as references.
async def _reading_identity(
    request: Request,
    identity: Annotated[IdentityContext, Depends(get_current_identity)],
) -> IdentityContext:
    kept = (
        None
        if identity.is_admin
        else frozenset({identity.tax_code, *identity.child_tax_codes})
    )
    keep_for_reader(kept)

    if kept is not None:
        setattr(request.state, KEPT_TAX_CODES_STATE_KEY, kept)

    return identity


CurrentIdentity = Annotated[IdentityContext, Depends(_reading_identity)]


def require_role(*roles: str) -> Callable[[CurrentIdentity], IdentityContext]:
    allowed = frozenset(roles)

    def _dependency(identity: CurrentIdentity) -> IdentityContext:
        if identity.roles.isdisjoint(allowed):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=tr(*_FORBIDDEN_ROLE_ERROR),
            )

        return identity

    return _dependency


# Writes only: an answered-for pupil still reads every booking of theirs.
async def assert_may_book_for(
    session: AsyncSession,
    identity: IdentityContext,
    student_tax_code: str,
) -> None:
    if identity.is_admin or student_tax_code in identity.bookable_student_tax_codes:
        return

    themself = "STUDENT" in identity.roles and student_tax_code == identity.tax_code

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=(
            await _who_books_for(session, student_tax_code)
            if themself
            else tr(*_FORBIDDEN_PUPIL_ERROR)
        ),
    )


async def _who_books_for(session: AsyncSession, student_tax_code: str) -> str:
    genders = list(
        await session.scalars(
            select(Person.gender)
            .join(
                ParentalResponsibility,
                ParentalResponsibility.parent_tax_code == Person.tax_code,
            )
            .where(ParentalResponsibility.child_tax_code == student_tax_code)
        )
    )

    if len(genders) != 1:
        return tr(*_PARENTS_BOOK_ERROR)

    return tr(*_PARENT_BOOKS_ERRORS[genders[0] or GenderEnum.M])


# For sentences about a pupil: no name when the reader is the pupil, else the
# first name for their parent and the full name for anybody else.
async def pupil_as_read(
    session: AsyncSession,
    identity: IdentityContext,
    student_tax_code: str,
) -> tuple[str | None, GenderEnum]:
    person = await session.get_one(Person, student_tax_code)
    gender = person.gender or GenderEnum.M

    if student_tax_code == identity.tax_code:
        return None, gender

    if student_tax_code in identity.child_tax_codes:
        return person.first_name, gender

    return f"{person.first_name} {person.last_name}", gender
