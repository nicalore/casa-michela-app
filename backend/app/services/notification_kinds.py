from collections.abc import Mapping, Sequence
from typing import Final

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.muted_notification_kind import MutedNotificationKind
from app.models.notification import NotificationKindEnum
from app.services.report_readers import kinds_read_by
from app.services.role_service import RoleService

_NOT_CHOOSABLE_ERROR: Final[str] = "Questo tipo di notifica non è tra i tuoi."

# Not a role: a pupil who books alone.
_SELF_BOOKER: Final[str] = "SELF_BOOKER"

# Not a role either: an administrator who receives reports.
_REPORT_READER: Final[str] = "REPORT_READER"

# Who may turn each kind on or off, in settings order; every kind but TEST is here.
CHOOSABLE: Final[dict[NotificationKindEnum, frozenset[str]]] = {
    NotificationKindEnum.BOOKINGS_CLOSED: frozenset({"ADMIN"}),
    NotificationKindEnum.CALENDAR_PUBLISHED: frozenset({"PARENT", "STUDENT"}),
    NotificationKindEnum.CONVOCATION: frozenset({"TEACHER"}),
    NotificationKindEnum.ARRIVAL_REMINDER: frozenset({"TEACHER"}),
    NotificationKindEnum.AVAILABILITY_OPENED: frozenset({"TEACHER"}),
    NotificationKindEnum.BOOKINGS_OPENED: frozenset(
        {"PARENT", _SELF_BOOKER},
    ),
    NotificationKindEnum.AVAILABILITY_REMINDER: frozenset({"TEACHER"}),
    NotificationKindEnum.BOOKING_REMINDER: frozenset({"PARENT", _SELF_BOOKER}),
    NotificationKindEnum.OPENING_HOURS_CHANGED: frozenset(
        {
            "ADMIN",
            "TEACHER",
            "PARENT",
            "STUDENT",
            "PSYCHOLOGIST",
            "COURSE_PARTICIPANT",
        },
    ),
    NotificationKindEnum.BOOKING_ADDED: frozenset({"PARENT", "STUDENT"}),
    NotificationKindEnum.BOOKING_CANCELLED: frozenset({"PARENT", "STUDENT"}),
    NotificationKindEnum.BOOKING_CHANGED: frozenset({"PARENT", "STUDENT"}),
    NotificationKindEnum.AVAILABILITY_ADDED: frozenset({"TEACHER"}),
    NotificationKindEnum.AVAILABILITY_CHANGED: frozenset({"TEACHER"}),
    NotificationKindEnum.AVAILABILITY_CANCELLED: frozenset({"TEACHER"}),
    NotificationKindEnum.NEW_DEVICE: frozenset(
        {
            "ADMIN",
            "TEACHER",
            "PARENT",
            "STUDENT",
            "PSYCHOLOGIST",
            "COURSE_PARTICIPANT",
        },
    ),
    NotificationKindEnum.NOTICE_RECEIVED: frozenset(
        {
            "ADMIN",
            "TEACHER",
            "PARENT",
            "STUDENT",
            "PSYCHOLOGIST",
            "COURSE_PARTICIPANT",
        },
    ),
    NotificationKindEnum.REPORT_RECEIVED: frozenset({_REPORT_READER}),
}


# A pupil whom nobody books for, or allowed to book alone.
def books_alone(account: Account) -> bool:
    return "STUDENT" in RoleService.get_available_roles(account.person) and (
        not RoleService.is_answered_for(account.person) or account.autonomous_bookings
    )


# The account's roles, a pupil who books alone counted as such too.
def _roles_of(account: Account) -> frozenset[str]:
    roles = set(RoleService.get_available_roles(account.person))

    if books_alone(account):
        roles.add(_SELF_BOOKER)

    if kinds_read_by(account.person):
        roles.add(_REPORT_READER)

    return frozenset(roles)


def holds_kind(account: Account, kind: NotificationKindEnum) -> bool:
    return bool(_roles_of(account) & CHOOSABLE.get(kind, frozenset()))


def choosable_by(account: Account) -> list[NotificationKindEnum]:
    roles = _roles_of(account)

    return [kind for kind, allowed in CHOOSABLE.items() if roles & allowed]


async def _muted(db: AsyncSession, tax_code: str) -> set[NotificationKindEnum]:
    return set(
        await db.scalars(
            select(MutedNotificationKind.kind).where(
                MutedNotificationKind.account_tax_code == tax_code,
            )
        )
    )


async def choices_of(
    db: AsyncSession,
    account: Account,
) -> list[tuple[NotificationKindEnum, bool]]:
    muted = await _muted(db, account.tax_code)

    return [(kind, kind not in muted) for kind in choosable_by(account)]


# The caller commits.
async def choose(
    db: AsyncSession,
    account: Account,
    wanted: Mapping[NotificationKindEnum, bool],
) -> None:
    allowed = set(choosable_by(account))

    if any(kind not in allowed for kind in wanted):
        raise ValueError(_NOT_CHOOSABLE_ERROR)

    on = [kind for kind, enabled in wanted.items() if enabled]
    off = [kind for kind, enabled in wanted.items() if not enabled]

    if on:
        await db.execute(
            delete(MutedNotificationKind).where(
                MutedNotificationKind.account_tax_code == account.tax_code,
                MutedNotificationKind.kind.in_(on),
            )
        )

    if off:
        rows = [{"account_tax_code": account.tax_code, "kind": kind} for kind in off]
        await db.execute(
            insert(MutedNotificationKind).values(rows).on_conflict_do_nothing()
        )


# Those of them who did not turn the kind off.
async def wanting(
    db: AsyncSession,
    tax_codes: Sequence[str],
    kind: NotificationKindEnum,
) -> list[str]:
    muted = set(
        await db.scalars(
            select(MutedNotificationKind.account_tax_code).where(
                MutedNotificationKind.kind == kind,
                MutedNotificationKind.account_tax_code.in_(list(tax_codes)),
            )
        )
    )

    return [tax_code for tax_code in tax_codes if tax_code not in muted]
