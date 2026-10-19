from collections.abc import Sequence
from typing import Final

from fastapi import APIRouter, BackgroundTasks, HTTPException, Response, status
from sqlalchemy import select

from app.api.current_account import CurrentAccount
from app.api.dependencies import DbSession
from app.core.labels import role_label
from app.models.administrator import AdministratorRoleEnum
from app.models.person import Person
from app.models.report import Report, ReportRead
from app.schemas.report import ReportCorrection, ReportResponse
from app.services import push
from app.services.report_readers import readable_by, reader_role
from app.services.reports import (
    deliver_resolved,
    report_opened,
    resolve_report,
    resolved_mail,
)

_NOT_A_READER_ERROR: Final[str] = "Non ricevi segnalazioni."
_REPORT_NOT_FOUND_ERROR: Final[str] = "Segnalazione non trovata."

# The reports a member sent in, for those who receive them by email.
router = APIRouter(prefix="/reports", tags=["reports"])


def _role_or_403(account: CurrentAccount) -> AdministratorRoleEnum:
    role = reader_role(account.person)

    if role is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=_NOT_A_READER_ERROR,
        )

    return role


def _full_name(person: Person | None) -> str | None:
    return None if person is None else f"{person.first_name} {person.last_name}"


async def _responses(
    db: DbSession,
    tax_code: str,
    reports: Sequence[Report],
) -> list[ReportResponse]:
    ids = [report.id for report in reports]
    read = set(
        await db.scalars(
            select(ReportRead.report_id).where(
                ReportRead.account_tax_code == tax_code,
                ReportRead.report_id.in_(ids),
            )
        )
    )
    codes = {report.reporter_tax_code for report in reports} | {
        report.person_tax_code for report in reports if report.person_tax_code
    }
    people = {
        person.tax_code: person
        for person in await db.scalars(
            select(Person).where(Person.tax_code.in_(codes))
        )
    }

    return [
        ReportResponse(
            id=report.id,
            kind=report.kind,
            created_at=report.created_at,
            read=report.id in read,
            reporter_tax_code=report.reporter_tax_code,
            reporter_name=_full_name(people[report.reporter_tax_code]) or "",
            reporter_email=people[report.reporter_tax_code].email,
            reporter_role=(
                role_label(report.reporter_role) if report.reporter_role else None
            ),
            person_tax_code=report.person_tax_code,
            person_name=_full_name(people.get(report.person_tax_code or "")),
            title=report.title,
            description=report.description,
            corrections=(
                None
                if report.corrections is None
                else [ReportCorrection(**item) for item in report.corrections]
            ),
        )
        for report in reports
    ]


async def _open_report_or_404(
    db: DbSession,
    report_id: int,
    role: AdministratorRoleEnum,
) -> Report:
    report = await db.scalar(
        select(Report).where(
            Report.id == report_id,
            readable_by(role),
            Report.resolved_at.is_(None),
        )
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_REPORT_NOT_FOUND_ERROR,
        )

    return report


@router.get("")
async def my_reports(
    current_account: CurrentAccount,
    db: DbSession,
) -> list[ReportResponse]:
    role = _role_or_403(current_account)
    reports = list(
        await db.scalars(
            select(Report)
            .where(readable_by(role), Report.resolved_at.is_(None))
            .order_by(Report.created_at.desc(), Report.id.desc())
        )
    )

    return await _responses(db, current_account.tax_code, reports)


# Opening one reads it, for the caller alone.
@router.get("/{report_id}")
async def open_report(
    report_id: int,
    current_account: CurrentAccount,
    db: DbSession,
) -> ReportResponse:
    report = await _open_report_or_404(
        db,
        report_id,
        _role_or_403(current_account),
    )
    await report_opened(db, report.id, current_account.tax_code)
    await db.commit()

    [response] = await _responses(db, current_account.tax_code, [report])

    return response


# Gone for every reader; its author is thanked by email.
@router.put("/{report_id}/resolve", status_code=status.HTTP_204_NO_CONTENT)
async def resolve(
    report_id: int,
    current_account: CurrentAccount,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    report = await _open_report_or_404(
        db,
        report_id,
        _role_or_403(current_account),
    )
    reporter = await db.get_one(Person, report.reporter_tax_code)
    mail = resolved_mail(report, reporter)
    batch = await resolve_report(db, report, current_account.tax_code)
    await db.commit()
    background.add_task(push.deliver, batch)
    background.add_task(deliver_resolved, mail)

    return Response(status_code=status.HTTP_204_NO_CONTENT)

