from typing import Final

from sqlalchemy import ColumnElement, and_, or_, true

from app.models.administrator import AdministratorRoleEnum
from app.models.person import Person
from app.models.report import Report, ReportKindEnum
from app.services.role_service import RoleService

_ADMIN: Final[str] = "ADMIN"

_IT_MANAGERS: Final[frozenset[AdministratorRoleEnum]] = frozenset(
    {AdministratorRoleEnum.IT_MANAGER},
)
_EVERY_ADMINISTRATOR: Final[frozenset[AdministratorRoleEnum]] = frozenset(
    AdministratorRoleEnum,
)

def audience(report: Report) -> frozenset[AdministratorRoleEnum]:
    if report.kind == ReportKindEnum.APP_PROBLEM or (
        report.kind == ReportKindEnum.PERSONAL_DATA
        and report.reporter_role == _ADMIN
        and report.person_tax_code != report.reporter_tax_code
    ):
        return _IT_MANAGERS

    return _EVERY_ADMINISTRATOR


# Mirrors audience, as a query condition.
def readable_by(role: AdministratorRoleEnum) -> ColumnElement[bool]:
    if role in _IT_MANAGERS:
        return true()

    return and_(
        Report.kind != ReportKindEnum.APP_PROBLEM,
        or_(
            Report.kind != ReportKindEnum.PERSONAL_DATA,
            Report.reporter_role.is_distinct_from(_ADMIN),
            Report.person_tax_code == Report.reporter_tax_code,
        ),
    )


# Only while the administrator's role holds: a lapsed one reads nothing.
def reader_role(person: Person) -> AdministratorRoleEnum | None:
    member = person.member_profile
    staff = member.staff_profile if member is not None else None
    administrator = staff.administrator_profile if staff is not None else None

    if administrator is None or _ADMIN not in RoleService.get_available_roles(person):
        return None

    return administrator.role


# The kinds some report of which may reach them, for their menu and filter.
def kinds_read_by(person: Person) -> list[ReportKindEnum]:
    role = reader_role(person)

    if role is None:
        return []

    return [
        kind
        for kind in ReportKindEnum
        if role in _IT_MANAGERS or kind != ReportKindEnum.APP_PROBLEM
    ]
