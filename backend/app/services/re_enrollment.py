from collections.abc import Sequence
from datetime import date, datetime
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.school_year import school_year_start
from app.models.member import Member
from app.models.membership import Membership, MembershipRevocationEnum
from app.models.membership_fee import MembershipFee
from app.models.school_enrollment import SchoolEnrollment
from app.models.student import Student
from app.models.student_payment import StudentPayment, StudentPaymentKindEnum
from app.models.student_tariff import TariffKindEnum
from app.schemas.person import SchoolEnrollmentUpdateItem
from app.schemas.re_enrollment import ReEnrollmentPayload
from app.schemas.student_payments import PaymentData, RenewalData
from app.services.membership_fees import first_fees
from app.services.student_payments import first_tariffs, renew, student_payment_status

_NOT_A_MEMBER_ERROR: Final[str] = "L'utente non possiede un profilo da associato."
_REVOKED_ERROR: Final[str] = "Con l'iscrizione revocata non si può rinnovare."
_WRONG_YEAR_ERROR: Final[str] = "La data di inizio deve essere nel {year}."
_ALREADY_ENROLLED_ERROR: Final[str] = "L'iscrizione del {year} c'è già."
_FEES_RECORDED_ERROR: Final[str] = "Le quote del {year} sono già registrate."
_NO_TARIFF_ERROR: Final[str] = "Manca la tariffa."
_NO_SCHOOL_YEAR_ERROR: Final[str] = "Manca l'anno scolastico in corso."
_EMPTY_SCHOOL_HISTORY_ERROR: Final[str] = "Indica almeno un anno scolastico."
_DUPLICATE_SCHOOL_YEAR_ERROR: Final[str] = "Un anno scolastico è ripetuto."
_START_TOO_LATE_ERROR: Final[str] = (
    "La data di inizio deve essere prima del 31 dicembre."
)
_MONTH_PAID_ERROR: Final[str] = "La quota di questo mese è già pagata."

# Memberships end on 31 December and stay renewable 31 days more.
_RENEWAL_PERIOD_DAYS: Final[int] = 31


def _refused(code: int, detail: str) -> HTTPException:
    return HTTPException(status_code=code, detail=detail)


async def _member(db: AsyncSession, tax_code: str) -> Member:
    member = await db.scalar(
        select(Member)
        .options(selectinload(Member.memberships))
        .where(Member.tax_code == tax_code),
    )

    if member is None:
        raise _refused(status.HTTP_404_NOT_FOUND, _NOT_A_MEMBER_ERROR)

    return member


def _check_year(member: Member, start: date, year: int) -> None:
    latest = max(member.memberships, key=lambda row: row.year, default=None)

    if latest is not None and latest.revocation != MembershipRevocationEnum.NO:
        raise _refused(status.HTTP_409_CONFLICT, _REVOKED_ERROR)

    if start.year != year:
        raise _refused(
            status.HTTP_400_BAD_REQUEST,
            _WRONG_YEAR_ERROR.format(year=year),
        )

    if latest is not None and latest.year >= year:
        raise _refused(
            status.HTTP_409_CONFLICT,
            _ALREADY_ENROLLED_ERROR.format(year=year),
        )

    # The year ends on 31 December: a start on it would leave no day enrolled.
    if start >= date(year, 12, 31):
        raise _refused(status.HTTP_400_BAD_REQUEST, _START_TOO_LATE_ERROR)


async def _rewrite_school_years(
    db: AsyncSession,
    tax_code: str,
    rows: Sequence[SchoolEnrollmentUpdateItem],
) -> None:
    if not rows:
        raise _refused(status.HTTP_400_BAD_REQUEST, _EMPTY_SCHOOL_HISTORY_ERROR)

    years = [row.start_year for row in rows]

    if len(years) != len(set(years)):
        raise _refused(status.HTTP_400_BAD_REQUEST, _DUPLICATE_SCHOOL_YEAR_ERROR)

    await db.execute(
        delete(SchoolEnrollment).where(SchoolEnrollment.student_tax_code == tax_code),
    )
    await db.flush()
    db.add_all(
        SchoolEnrollment(
            student_tax_code=tax_code,
            start_year=row.start_year,
            grade=row.grade,
            study_program_id=row.study_program_id,
            school_id=row.school_id,
            homeschooling=row.homeschooling,
        )
        for row in rows
    )
    await db.flush()


# The school year in course says the level the tariff is for.
async def _program_now(db: AsyncSession, tax_code: str, today: date) -> int:
    latest = await db.scalar(
        select(SchoolEnrollment)
        .where(SchoolEnrollment.student_tax_code == tax_code)
        .order_by(SchoolEnrollment.start_year.desc())
        .limit(1),
    )

    if latest is None or latest.start_year != school_year_start(today):
        raise _refused(status.HTTP_400_BAD_REQUEST, _NO_SCHOOL_YEAR_ERROR)

    return latest.study_program_id


# From today, like at creation; package hours or hours paid ahead still left
# keep the new row waiting until they end (the payment walk's rule).
async def _new_tariff(
    db: AsyncSession,
    tax_code: str,
    payload: ReEnrollmentPayload,
    now: datetime,
) -> None:
    today = now.date()

    if payload.school_enrollments is not None:
        await _rewrite_school_years(db, tax_code, payload.school_enrollments)

    program = await _program_now(db, tax_code, today)
    before = (await student_payment_status(db, tax_code, now)).status

    # A change already chosen and waiting to start stays the pupil's tariff: one
    # more row would jump over it, and over what was paid for it.
    if before is not None and before.queued == "CHANGE":
        return

    tariff = payload.tariff

    if tariff is None:
        raise _refused(status.HTTP_400_BAD_REQUEST, _NO_TARIFF_ERROR)

    (row,) = await first_tariffs(db, tariff, program, today)
    row.student_tax_code = tax_code
    db.add(row)
    await db.flush()

    if not tariff.paid:
        return

    paid = PaymentData(
        paid_on=today,
        payment_method=payload.payment_method,
        payment_method_other=payload.payment_method_other,
    )
    running = (await student_payment_status(db, tax_code, now)).status

    if running is not None and running.tariff.id == row.id:
        # Renewing a month already paid would buy the one after it.
        if tariff.kind == TariffKindEnum.MONTHLY and running.month_paid:
            raise _refused(status.HTTP_409_CONFLICT, _MONTH_PAID_ERROR)

        await renew(
            db,
            tax_code,
            RenewalData(
                amount_cents=tariff.amount_cents,
                package_hours=tariff.package_hours,
                payment=paid,
            ),
            now,
        )

        return

    # Bought now, used from the row's first day: a fee then pays its first month.
    package = tariff.kind == TariffKindEnum.PACKAGE
    kind = StudentPaymentKindEnum.PACKAGE if package else StudentPaymentKindEnum.MONTH
    db.add(
        StudentPayment(
            student_tax_code=tax_code,
            kind=kind,
            tariff_id=row.id,
            package_hours=tariff.package_hours if package else None,
            amount_cents=tariff.amount_cents,
            paid_on=paid.paid_on,
            payment_method=paid.payment_method,
            payment_method_other=paid.payment_method_other,
        )
    )
    await db.flush()


async def re_enroll(
    db: AsyncSession,
    tax_code: str,
    payload: ReEnrollmentPayload,
    now: datetime,
) -> None:
    member = await _member(db, tax_code)
    today = now.date()
    year = today.year

    _check_year(member, payload.start_date, year)

    recorded = await db.scalar(
        select(MembershipFee.id)
        .where(MembershipFee.member_tax_code == tax_code, MembershipFee.year == year)
        .limit(1),
    )

    if recorded is not None:
        raise _refused(
            status.HTTP_409_CONFLICT,
            _FEES_RECORDED_ERROR.format(year=year),
        )

    db.add(
        Membership(
            member_tax_code=tax_code,
            year=year,
            start_date=payload.start_date,
            end_date=date(year, 12, 31),
            renewal_period_days=_RENEWAL_PERIOD_DAYS,
        )
    )
    member.payment_method = payload.payment_method
    member.payment_method_other = payload.payment_method_other
    member.updated_at = now
    db.add_all(
        first_fees(
            tax_code,
            year,
            payload.fees,
            payload.payment_method,
            payload.payment_method_other,
            today,
        )
    )
    await db.flush()

    if await db.get(Student, tax_code) is not None:
        await _new_tariff(db, tax_code, payload, now)

