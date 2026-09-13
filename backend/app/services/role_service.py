from collections.abc import Iterable
from typing import ClassVar, Final

from fastapi import HTTPException, status

from app.core.labels import role_label
from app.models.administrator import AdministratorRoleEnum
from app.models.person import Person
from app.models.staff import CollaborationTypeEnum

_UNPAID_ADMIN_ROLE_ERROR: Final[str] = (
    "Presidente, Vicepresidente e Tesoriere devono avere "
    "tipo di collaborazione 'Non pagato'."
)


class RoleService:
    # Roles with a UI to land on; mirrors _homeByRole in frontend/lib/routing/app_router.dart.
    ROLES_WITH_UI: ClassVar[frozenset[str]] = frozenset(
        {
            "ADMIN",
            "TEACHER",
            "PARENT",
            "STUDENT",
        }
    )

    ADMIN_ROLES_REQUIRING_UNPAID: ClassVar[set[AdministratorRoleEnum]] = {
        AdministratorRoleEnum.PRESIDENT,
        AdministratorRoleEnum.VICE_PRESIDENT,
        AdministratorRoleEnum.TREASURER,
    }

    @staticmethod
    def get_available_roles(person: Person) -> list[str]:
        roles: list[str] = []

        if person.parent_profile is not None:
            roles.append("PARENT")

        member = person.member_profile

        if member is None:
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

        # Psychologists and course participants have no home yet, but still need a label.
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