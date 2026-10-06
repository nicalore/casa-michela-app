from collections.abc import Iterable
from datetime import timedelta
from typing import ClassVar, Final

from fastapi import HTTPException, status

from app.core.booking_window import today_in_rome
from app.core.labels import role_label
from app.models.account import AccessLapseEnum
from app.models.administrator import AdministratorRoleEnum
from app.models.member import Member
from app.models.membership import MembershipRevocationEnum
from app.models.person import Person
from app.models.staff import CollaborationTypeEnum

_UNPAID_ADMIN_ROLE_ERROR: Final[str] = (
    "Presidente, Vicepresidente e Tesoriere devono avere "
    "tipo di collaborazione 'Non pagato'."
)

# Mirrored by frontend/lib/features/auth/models/me_response.dart.
BOARD_ROLES: Final[frozenset[AdministratorRoleEnum]] = frozenset(
    {
        AdministratorRoleEnum.PRESIDENT,
        AdministratorRoleEnum.VICE_PRESIDENT,
        AdministratorRoleEnum.TREASURER,
    }
)


class RoleService:
    # Roles with a UI; mirrors _homeByRole in frontend/lib/routing/app_router.dart.
    ROLES_WITH_UI: ClassVar[frozenset[str]] = frozenset(
        {
            "ADMIN",
            "TEACHER",
            "PARENT",
            "STUDENT",
            "PSYCHOLOGIST",
        }
    )

    ADMIN_ROLES_REQUIRING_UNPAID: ClassVar[set[AdministratorRoleEnum]] = {
        AdministratorRoleEnum.PRESIDENT,
        AdministratorRoleEnum.VICE_PRESIDENT,
        AdministratorRoleEnum.TREASURER,
    }

    # The register's rule (people._enrolled): latest membership, unrevoked, in window.
    @staticmethod
    def is_enrolled(member: Member | None) -> bool:
        if member is None or not member.memberships:
            return False

        latest = max(member.memberships, key=lambda membership: membership.year)
        lapses_on = latest.end_date + timedelta(days=latest.renewal_period_days)

        return (
            latest.revocation == MembershipRevocationEnum.NO
            and lapses_on > today_in_rome()
        )

    # The board keeps its roles past a lapse: somebody must be able to renew.
    @staticmethod
    def in_good_standing(member: Member) -> bool:
        staff = member.staff_profile
        administrator = staff.administrator_profile if staff is not None else None

        if administrator is not None and administrator.role in BOARD_ROLES:
            return True

        return RoleService.is_enrolled(member)

    # Enrolled pupils only: a minor on the staff has parents for paperwork alone.
    @staticmethod
    def pupil_children_tax_codes(person: Person) -> frozenset[str]:
        parent = person.parent_profile

        if parent is None:
            return frozenset()

        return frozenset(
            relationship.child_tax_code
            for relationship in parent.children_relationships
            if relationship.child.member_profile is not None
            and relationship.child.member_profile.student_profile is not None
            and RoleService.is_enrolled(relationship.child.member_profile)
        )

    # None while some enrollment stands behind the account.
    @staticmethod
    def access_lapse(person: Person) -> AccessLapseEnum | None:
        member = person.member_profile

        if member is not None and RoleService.in_good_standing(member):
            return None

        if RoleService.pupil_children_tax_codes(person):
            return None

        if member is not None:
            return AccessLapseEnum.MEMBERSHIP

        return AccessLapseEnum.CHILDREN

    # Only pupils are answered for, not staff minors.
    @staticmethod
    def is_answered_for(person: Person) -> bool:
        member = person.member_profile

        return (
            member is not None
            and member.student_profile is not None
            and bool(person.parental_relationships)
        )

    @staticmethod
    def get_available_roles(person: Person) -> list[str]:
        roles: list[str] = []

        if RoleService.pupil_children_tax_codes(person):
            roles.append("PARENT")

        member = person.member_profile

        if member is None or not RoleService.in_good_standing(member):
            return roles

        if member.student_profile is not None:
            roles.append("STUDENT")

        if member.course_participant_profile is not None:
            roles.append("COURSE_PARTICIPANT")

        staff = member.staff_profile

        if staff is None:
            return roles

        if staff.administrator_profile is not None:
            roles.append("ADMIN")

        if staff.teacher_profile is not None:
            roles.append("TEACHER")

        if staff.psychologist_profile is not None:
            roles.append("PSYCHOLOGIST")

        return roles

    # Sorted by the label the user reads, not by the role code.
    @staticmethod
    def sorted_by_label(roles: Iterable[str]) -> list[str]:
        return sorted(roles, key=role_label)

    @staticmethod
    def resolve_active_role(
        roles: Iterable[str],
        last_active_role: str | None,
    ) -> str | None:
        available = list(roles)

        # A role since taken away must not strand the account on an unusable page.
        if (
            last_active_role in available
            and last_active_role in RoleService.ROLES_WITH_UI
        ):
            return last_active_role

        usable = [role for role in available if role in RoleService.ROLES_WITH_UI]

        if usable:
            return RoleService.sorted_by_label(usable)[0]

        # Course participants have no home yet, but need a label.
        if available:
            return RoleService.sorted_by_label(available)[0]

        return None

    @staticmethod
    def assert_collaboration_type_consistent_with_admin_role(
        role: AdministratorRoleEnum,
        collaboration_type: CollaborationTypeEnum,
    ) -> None:
        if (
            role in RoleService.ADMIN_ROLES_REQUIRING_UNPAID
            and collaboration_type != CollaborationTypeEnum.UNPAID
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=_UNPAID_ADMIN_ROLE_ERROR,
            )