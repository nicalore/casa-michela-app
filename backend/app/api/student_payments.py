from collections import defaultdict
from datetime import date
from typing import Annotated, Final, Literal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.core.i18n import tr
from app.models.member import Member
from app.models.membership_fee import MembershipFee, MembershipFeeKindEnum
from app.models.person import GenderEnum
from app.models.student import Student
from app.models.student_payment import StudentPayment
from app.repositories.person_repository import PersonRepository
from app.schemas.student_payments import (
    AheadData,
    AheadStatusResponse,
    HistoryLessonResponse,
    HistoryRowResponse,
    HoursLineResponse,
    LessonPartResponse,
    MonthStateResponse,
    PackageStatusResponse,
    PaymentData,
    RenewalData,
    SettlementData,
    SettlementsData,
    StudentPaymentsResponse,
    StudentTariffResponse,
    TariffChangeData,
)
from app.services import student_payments as payments_service
from app.services.accounting_lock import lock_account
from app.services.membership_fees import (
    cancel_fee_payment,
    member_fees,
    settle_fee,
)
from app.services.opening_state import refuse_pending_pupil
from app.services.role_service import RoleService
from app.services.student_payments import (
    HistoryRow,
    days_interleaved,
    student_payment_status,
)

router = APIRouter(prefix="/people", tags=["student-payments"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]
Reader = Annotated[
    IdentityContext,
    Depends(require_role("ADMIN", "TEACHER", "PARENT", "STUDENT")),
]

# A database integer: anything larger would fail in the driver, not as a 404.
RowId = Annotated[int, Path(ge=1, le=2**31 - 1)]

_STUDENT_NOT_FOUND_ERROR: Final[tuple[str, str]] = (
    "Studente non trovato",
    "Student not found",
)

_MEMBER_NOT_FOUND_ERROR: Final[tuple[str, str]] = (
    "Socio non trovato",
    "Member not found",
)

_FORBIDDEN_ERROR: Final[tuple[str, str]] = (
    "Non hai i permessi per accedere a questa risorsa",
    "You don't have permission to access this resource",
)

_READ_ONLY_ERRORS: Final[dict[GenderEnum, tuple[str, str]]] = {
    GenderEnum.M: (
        "Non è iscritto quest’anno: si può solo saldare quello che resta da pagare.",
        "He isn't enrolled this year: only what is still owed can be paid.",
    ),
    GenderEnum.F: (
        "Non è iscritta quest’anno: si può solo saldare quello che resta da pagare.",
        "She isn't enrolled this year: only what is still owed can be paid.",
    ),
}

FeeRowKind = Literal["MEMBERSHIP_FEE", "INSURANCE_FEE"]

_FEE_KINDS: Final[dict[MembershipFeeKindEnum, FeeRowKind]] = {
    MembershipFeeKindEnum.MEMBERSHIP: "MEMBERSHIP_FEE",
    MembershipFeeKindEnum.INSURANCE: "INSURANCE_FEE",
}


async def _member_or_404(
    db: AsyncSession,
    code: str,
    *,
    student: bool = False,
) -> Member:
    query = (
        select(Member)
        .options(selectinload(Member.memberships))
        .where(Member.tax_code == code)
    )

    if student:
        query = query.join(Student, Student.tax_code == Member.tax_code)

    member = await db.scalar(query)

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=tr(
                *(_STUDENT_NOT_FOUND_ERROR if student else _MEMBER_NOT_FOUND_ERROR)
            ),
        )

    return member


# Whoever is not enrolled buys nothing new: what is owed can still be settled.
async def _writable(db: AsyncSession, member: Member) -> None:
    if not RoleService.is_enrolled(member):
        gender = await PersonRepository(db).gender(member.tax_code)

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=tr(*_READ_ONLY_ERRORS[gender]),
        )


_ROME: Final[ZoneInfo] = ZoneInfo("Europe/Rome")


def _fee_row(fee: MembershipFee) -> HistoryRowResponse:
    return HistoryRowResponse(
        kind=_FEE_KINDS[fee.kind],
        paid_on=fee.paid_on,
        payment_method=fee.payment_method,
        payment_method_other=fee.payment_method_other,
        amount_cents=fee.amount_cents,
        minutes=0,
        package_hours=None,
        month=None,
        ahead_minutes=None,
        state=None,
        lessons=[],
        year=fee.year,
        fee_id=fee.id,
        recorded_on=fee.created_at.astimezone(_ROME).date(),
    )


# Every day of each kind of row: a row whose span holds another's lesson names
# its days instead.
def _kind_days(rows: list[HistoryRowResponse]) -> dict[str, set[date]]:
    days: dict[str, set[date]] = defaultdict(set)

    for row in rows:
        days[row.kind].update(lesson.day for lesson in row.lessons)

    return days


def _interleaved(rows: list[HistoryRowResponse]) -> list[HistoryRowResponse]:
    days = _kind_days(rows)

    return [
        row.model_copy(
            update={
                "interleaved": days_interleaved(
                    [lesson.day for lesson in row.lessons],
                    days[row.kind],
                ),
            },
        )
        for row in rows
    ]


# Fees owed first, then hours to settle, then everything paid, the newest first.
def _merged(
    rows: list[HistoryRowResponse],
    fees: list[MembershipFee],
) -> list[HistoryRowResponse]:
    owed = [_fee_row(fee) for fee in reversed(fees) if fee.paid_on is None]
    due = [row for row in rows if row.paid_on is None]
    paid = [row for row in rows if row.paid_on is not None]
    paid += [_fee_row(fee) for fee in fees if fee.paid_on is not None]
    paid.sort(key=lambda row: row.paid_on or date.min, reverse=True)

    return owed + due + paid


def _history_row(row: HistoryRow) -> HistoryRowResponse:
    payment = row.payment

    return HistoryRowResponse(
        kind=row.kind,
        paid_on=payment.paid_on if payment is not None else None,
        payment_method=payment.payment_method if payment is not None else None,
        payment_method_other=(
            payment.payment_method_other if payment is not None else None
        ),
        amount_cents=row.amount_cents,
        minutes=row.minutes,
        package_hours=row.package_hours,
        month=row.month,
        ahead_minutes=row.ahead_minutes,
        state=row.state,
        lessons=[
            HistoryLessonResponse(
                day=lesson.day,
                minutes=lesson.minutes,
                lesson_minutes=lesson.lesson_minutes,
                left_minutes=lesson.left_minutes,
                cents=lesson.cents,
                exhausted=lesson.exhausted,
                before_payment=lesson.before_payment,
                opening=lesson.opening,
            )
            for lesson in row.lessons
        ],
        payment_id=payment.id if payment is not None else None,
    )


async def _response(db: AsyncSession, member: Member) -> StudentPaymentsResponse:
    student = await db.get(Student, member.tax_code) is not None
    fees = await member_fees(db, member.tax_code)
    owed = sum(fee.amount_cents for fee in fees if fee.paid_on is None)
    found = (
        await student_payment_status(db, member.tax_code, now_in_rome())
        if student
        else None
    )
    payment = found.status if found is not None else None
    last_payment = found.last_payment if found is not None else None
    last_fee = max(
        (fee for fee in fees if fee.paid_on is not None),
        key=lambda fee: (fee.paid_on, fee.id),
        default=None,
    )
    last: StudentPayment | MembershipFee | None = last_payment

    if last_fee is not None and (
        last_payment is None
        or (last_fee.paid_on is not None and last_fee.paid_on > last_payment.paid_on)
    ):
        last = last_fee

    method = (
        last.payment_method
        if last is not None and last.payment_method is not None
        else member.payment_method
    )
    other = (
        last.payment_method_other
        if last is not None and last.payment_method is not None
        else member.payment_method_other
    )
    history = _interleaved(
        _merged(
            [_history_row(row) for row in found.history] if found is not None else [],
            fees,
        ),
    )
    kind_days = _kind_days(history)
    read_only = not RoleService.is_enrolled(member)
    level = found.level if found is not None else None
    opening = found.opening if found is not None else None
    opening_day = found.opening_day if found is not None else None
    weekend_rate = found.rates.weekend_online_cents if found is not None else None

    if payment is None:
        return StudentPaymentsResponse(
            student=student,
            opening=opening,
            opening_day=opening_day,
            read_only=read_only,
            tariff=None,
            school_level=level,
            payment_method=method,
            payment_method_other=other,
            state=("DUE" if owed else "OK") if fees else None,
            due_cents=owed,
            package=None,
            months=None,
            ahead=None,
            weekend_online_cents=weekend_rate,
            lines=[],
            queued=None,
            queued_starts_on=None,
            history=history,
        )

    current_id = payment.tariff.id

    return StudentPaymentsResponse(
        student=student,
        opening=opening,
        opening_day=opening_day,
        read_only=read_only,
        tariff=StudentTariffResponse(
            kind=payment.tariff.kind,
            amount_cents=payment.amount_cents,
            package_hours=payment.package_hours,
            starts_on=payment.started_on,
        ),
        school_level=level,
        payment_method=method,
        payment_method_other=other,
        state="DUE" if payment.state == "OK" and owed else payment.state,
        due_cents=payment.due_cents + owed,
        package=(
            PackageStatusResponse(
                total_minutes=payment.package.hours * 60,
                used_minutes=payment.package.used_minutes,
                ended_on=payment.package.ended_on,
            )
            if payment.package is not None
            else None
        ),
        months=(
            [
                MonthStateResponse(month=month, state=state)
                for month, state in payment.months
            ]
            if payment.months is not None
            else None
        ),
        ahead=(
            AheadStatusResponse(
                total_minutes=payment.ahead.total_minutes,
                used_minutes=payment.ahead.used_minutes,
            )
            if payment.ahead is not None
            else None
        ),
        weekend_ahead=(
            AheadStatusResponse(
                total_minutes=payment.weekend_ahead.total_minutes,
                used_minutes=payment.weekend_ahead.used_minutes,
            )
            if payment.weekend_ahead is not None
            else None
        ),
        weekend_online_cents=weekend_rate,
        lines=[
            HoursLineResponse(
                kind=line.kind,
                minutes=line.minutes,
                cents=line.cents,
                cents_per_hour=line.cents_per_hour,
                parts=[
                    LessonPartResponse(
                        day=part.day,
                        minutes=part.minutes,
                        current=part.tariff_id == current_id,
                        opening=part.opening,
                        cents=part.cents,
                    )
                    for part in line.parts
                ],
                interleaved=days_interleaved(
                    [part.day for part in line.parts],
                    kind_days[line.kind.value],
                ),
            )
            for line in payment.lines
        ],
        queued=payment.queued,
        queued_starts_on=payment.queued_starts_on,
        queued_tariff=(
            None
            if payment.queued_tariff is None
            else StudentTariffResponse(
                kind=payment.queued_tariff.kind,
                amount_cents=payment.queued_tariff.amount_cents,
                package_hours=payment.queued_tariff.package_hours,
                starts_on=payment.queued_tariff.starts_on,
            )
        ),
        history=history,
    )


# A teacher's or a parent's own: their annual fees alone, read only.
async def _fees_response(
    db: AsyncSession,
    member: Member,
) -> StudentPaymentsResponse:
    fees = await member_fees(db, member.tax_code)
    owed = sum(fee.amount_cents for fee in fees if fee.paid_on is None)
    last = max(
        (fee for fee in fees if fee.paid_on is not None),
        key=lambda fee: (fee.paid_on, fee.id),
        default=None,
    )
    paid_by = last is not None and last.payment_method is not None

    return StudentPaymentsResponse(
        student=False,
        opening=None,
        opening_day=None,
        read_only=True,
        tariff=None,
        school_level=None,
        payment_method=last.payment_method if paid_by else member.payment_method,
        payment_method_other=(
            last.payment_method_other if paid_by else member.payment_method_other
        ),
        state=("DUE" if owed else "OK") if fees else None,
        due_cents=owed,
        package=None,
        months=None,
        ahead=None,
        lines=[],
        queued=None,
        queued_starts_on=None,
        history=_merged([], fees),
    )


# A parent reading a child, or a pupil nobody answers for reading their own.
def _family(identity: IdentityContext, tax_code: str) -> bool:
    if "PARENT" in identity.roles and tax_code in identity.child_tax_codes:
        return True

    return (
        tax_code == identity.tax_code
        and "STUDENT" in identity.roles
        and not identity.answered_for
    )


ReaderView = Literal["ALL", "FEES"]


# Under the admin hat, or reading someone else as an admin: everything.
def _view_of(identity: IdentityContext, tax_code: str) -> ReaderView:
    own = tax_code == identity.tax_code

    if identity.reads_everything or (identity.is_admin and not own):
        return "ALL"

    # A family reads what an admin reads: what is owed, renewals, hours ahead.
    if _family(identity, tax_code):
        return "ALL"

    # A teacher's or a parent's own: their annual fees.
    if own and not identity.roles.isdisjoint({"TEACHER", "PARENT"}):
        return "FEES"

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=tr(*_FORBIDDEN_ERROR),
    )


@router.get("/{tax_code}/payments", response_model=StudentPaymentsResponse)
async def student_payments(
    tax_code: str,
    db: DbSession,
    identity: Reader,
) -> StudentPaymentsResponse:
    code = tax_code.upper()
    view = _view_of(identity, code)
    member = await _member_or_404(db, code)

    if view == "FEES":
        return await _fees_response(db, member)

    return await _response(db, member)


# Renewing is paying: the package or month bought starts when the running one ends.
@router.post(
    "/{tax_code}/payments/renewal",
    response_model=StudentPaymentsResponse,
)
async def renew(
    tax_code: str,
    payload: RenewalData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=True)
    await _writable(db, member)
    await refuse_pending_pupil(db, member.tax_code)
    await payments_service.renew(db, member.tax_code, payload, now_in_rome())
    await db.commit()

    return await _response(db, member)


@router.post(
    "/{tax_code}/payments/tariff",
    response_model=StudentPaymentsResponse,
)
async def change_tariff(
    tax_code: str,
    payload: TariffChangeData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=True)
    await _writable(db, member)
    await refuse_pending_pupil(db, member.tax_code)
    await payments_service.change_tariff(db, member.tax_code, payload, now_in_rome())
    await db.commit()

    return await _response(db, member)


# Hours paid before they are done: lessons by the hour, or online at the weekend,
# draw on them first.
@router.post(
    "/{tax_code}/payments/ahead",
    response_model=StudentPaymentsResponse,
)
async def pay_ahead(
    tax_code: str,
    payload: AheadData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=True)
    await _writable(db, member)
    await refuse_pending_pupil(db, member.tax_code)
    await payments_service.pay_ahead(db, member.tax_code, payload, now_in_rome())
    await db.commit()

    return await _response(db, member)


@router.post(
    "/{tax_code}/payments/settlement",
    response_model=StudentPaymentsResponse,
)
async def settle(
    tax_code: str,
    payload: SettlementData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=True)
    await refuse_pending_pupil(db, member.tax_code)
    await payments_service.settle(db, member.tax_code, payload, now_in_rome())
    await db.commit()

    return await _response(db, member)


# The settle window: the lines of hours and the fees ticked, one day and one way.
@router.post(
    "/{tax_code}/payments/settlements",
    response_model=StudentPaymentsResponse,
)
async def settle_items(
    tax_code: str,
    payload: SettlementsData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=bool(payload.hours))
    now = now_in_rome()

    # Fees are paid whatever the initial set-up; hours wait for it.
    if payload.hours:
        await refuse_pending_pupil(db, member.tax_code)

    for choice in payload.hours:
        await payments_service.settle(
            db,
            member.tax_code,
            SettlementData(**choice.model_dump(), payment=payload.payment),
            now,
        )

    for fee_id in payload.fee_ids:
        await settle_fee(db, member.tax_code, fee_id, payload.payment, now.date())

    await db.commit()

    return await _response(db, member)


# An annual fee owed, paid now.
@router.post(
    "/{tax_code}/payments/fees/{fee_id}/settlement",
    response_model=StudentPaymentsResponse,
)
async def settle_membership_fee(
    tax_code: str,
    fee_id: RowId,
    payload: PaymentData,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper())
    await settle_fee(db, member.tax_code, fee_id, payload, now_in_rome().date())
    await db.commit()

    return await _response(db, member)


# A payment taken back: the hours it covered or settled are to settle again.
@router.delete(
    "/{tax_code}/payments/{payment_id}",
    response_model=StudentPaymentsResponse,
)
async def cancel_payment(
    tax_code: str,
    payment_id: RowId,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper(), student=True)
    await refuse_pending_pupil(db, member.tax_code)
    await payments_service.cancel_payment(db, member.tax_code, payment_id)
    await db.commit()

    return await _response(db, member)


# An annual fee paid by mistake: owed again.
@router.delete(
    "/{tax_code}/payments/fees/{fee_id}/settlement",
    response_model=StudentPaymentsResponse,
)
async def cancel_membership_fee_payment(
    tax_code: str,
    fee_id: RowId,
    db: DbSession,
    _: Admin,
) -> StudentPaymentsResponse:
    await lock_account(db, tax_code.upper())
    member = await _member_or_404(db, tax_code.upper())
    await cancel_fee_payment(db, member.tax_code, fee_id)
    await db.commit()

    return await _response(db, member)
