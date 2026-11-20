from collections import defaultdict
from collections.abc import Sequence
from datetime import date
from typing import Final

from fastapi import HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.i18n import request_language, tr
from app.core.labels import month_name
from app.models.accounting_opening import (
    AccountingOpening,
    PupilOpening,
    TeacherOpening,
)
from app.models.administrator import Administrator
from app.models.member import PaymentMethodEnum
from app.models.person import GenderEnum, Person
from app.models.school_enrollment import SchoolEnrollment
from app.models.staff import CollaborationTypeEnum, Staff
from app.models.student_payment import StudentPayment, StudentPaymentKindEnum
from app.models.student_tariff import StudentTariff, TariffKindEnum
from app.models.study_program import EducationLevelEnum, StudyProgram
from app.repositories.person_repository import PersonRepository
from app.schemas.accounting_opening import (
    OpeningAheadResponse,
    OpeningPaymentResponse,
    OpeningPupilResponse,
    OpeningTariffResponse,
    OpeningTeacherResponse,
    PupilOpeningData,
    StandardOfLevelResponse,
    TeacherOpeningData,
)
from app.schemas.student_payments import PaymentData
from app.services.bilingual import Bilingual
from app.services.compensation import load_terms, set_terms
from app.services.opening_state import (
    accounting_opening,
    collaborating,
    day_before,
)
from app.services.role_service import RoleService
from app.services.standard_tariffs import enabled_kinds, rates_of, standard_tariffs
from app.services.student_payments import school_level

_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Configurazione iniziale non trovata.",
    "Initial setup not found.",
)
_CLOSED_ERROR: Final[Bilingual] = Bilingual(
    "La configurazione iniziale è chiusa.",
    "The initial setup is closed.",
)
_NOT_LISTED_ERROR: Final[Bilingual] = Bilingual(
    "Questa persona non è nella configurazione iniziale.",
    "This person is not in the initial setup.",
)
_STILL_PENDING_ERROR: Final[Bilingual] = Bilingual(
    "Ci sono ancora docenti o studenti da configurare.",
    "There are still teachers or students to set up.",
)
_RATE_REQUIRED_ERROR: Final[Bilingual] = Bilingual(
    "Manca il compenso orario.",
    "The hourly pay is missing.",
)
_KIND_NOT_CHOSEN_ERROR: Final[Bilingual] = Bilingual(
    "Questa collaborazione non si sceglie qui.",
    "This collaboration is not chosen here.",
)
_GROSS_REQUIRED_ERROR: Final[Bilingual] = Bilingual(
    "Manca il compenso.",
    "The pay is missing.",
)
_KIND_DISABLED_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Questa tariffa è disattivata per il livello dello studente.",
        "This rate is turned off for the student's level.",
    ),
    GenderEnum.F: Bilingual(
        "Questa tariffa è disattivata per il livello della studentessa.",
        "This rate is turned off for the student's level.",
    ),
}
_OTHER_TARIFF_PAID_ERROR: Final[Bilingual] = Bilingual(
    "Dopo l'inizio della contabilità ci sono pagamenti con un'altra tariffa.",
    "After the accounting starts there are payments with another rate.",
)

_PAID_KINDS: Final[dict[StudentPaymentKindEnum, TariffKindEnum]] = {
    StudentPaymentKindEnum.PACKAGE: TariffKindEnum.PACKAGE,
    StudentPaymentKindEnum.MONTH: TariffKindEnum.MONTHLY,
    StudentPaymentKindEnum.AHEAD: TariffKindEnum.HOURLY,
}


def _not_found(detail: str = _NOT_FOUND_ERROR.for_request()) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


async def opening_or_404(db: AsyncSession) -> AccountingOpening:
    opening = await accounting_opening(db)

    if opening is None:
        raise _not_found()

    return opening


def assert_open(opening: AccountingOpening) -> None:
    if opening.closed_at is not None:
        raise _conflict(_CLOSED_ERROR.for_request())


def _late_payment_error(last_day: date) -> str:
    language = request_language()
    day = f"{last_day.day} {month_name(last_day.month, language)}"

    return tr(
        f"La data del pagamento è dopo il {day}.",
        f"The payment date is after {day}.",
    )


async def _people(
    db: AsyncSession,
    tax_codes: Sequence[str],
) -> dict[str, Person]:
    if not tax_codes:
        return {}

    return {
        person.tax_code: person
        for person in await db.scalars(
            select(Person).where(Person.tax_code.in_(tax_codes)),
        )
    }


def _sorted(people: dict[str, Person]) -> list[str]:
    return sorted(
        people,
        key=lambda code: (
            people[code].last_name.casefold(),
            people[code].first_name.casefold(),
        ),
    )


async def _can_edit(db: AsyncSession, tax_code: str) -> bool:
    role = await db.scalar(
        select(Administrator.role).where(Administrator.tax_code == tax_code),
    )

    return role not in RoleService.ADMIN_ROLES_REQUIRING_UNPAID


async def _teacher_response(
    db: AsyncSession,
    opening: AccountingOpening,
    row: TeacherOpening,
    person: Person,
) -> OpeningTeacherResponse:
    terms = (await load_terms(db, row.tax_code)).of_month(
        opening.money_from.replace(day=1),
    )

    return OpeningTeacherResponse(
        tax_code=row.tax_code,
        first_name=person.first_name,
        last_name=person.last_name,
        gender=person.gender,
        profile_image_url=person.profile_image_url,
        confirmed=row.confirmed_at is not None,
        collaboration_type=terms.collaboration_type.value,
        gross_rate=terms.rate,
        can_edit=await _can_edit(db, row.tax_code),
        gross=row.gross,
    )


async def teachers_listed(
    db: AsyncSession,
    opening: AccountingOpening,
) -> list[OpeningTeacherResponse]:
    rows = {row.tax_code: row for row in await db.scalars(select(TeacherOpening))}
    active = await collaborating(db, list(rows))
    people = await _people(db, [code for code in rows if code in active])

    return [
        await _teacher_response(db, opening, rows[code], people[code])
        for code in _sorted(people)
    ]


async def _levels(
    db: AsyncSession,
    tax_codes: Sequence[str],
) -> dict[str, EducationLevelEnum]:
    levels: dict[str, EducationLevelEnum] = {}
    rows = await db.execute(
        select(SchoolEnrollment.student_tax_code, StudyProgram.level)
        .join(StudyProgram, SchoolEnrollment.study_program_id == StudyProgram.id)
        .where(SchoolEnrollment.student_tax_code.in_(tax_codes))
        .order_by(
            SchoolEnrollment.student_tax_code,
            SchoolEnrollment.start_year.desc(),
        ),
    )

    for tax_code, level in rows.tuples():
        levels.setdefault(tax_code, level)

    return levels


def _in_force(rows: Sequence[StudentTariff], day: date) -> StudentTariff | None:
    earlier = [row for row in rows if row.starts_on <= day]

    return max(earlier, key=lambda row: (row.starts_on, row.id), default=None)


def _paid(payment: StudentPayment) -> OpeningPaymentResponse:
    return OpeningPaymentResponse(
        paid_on=payment.paid_on,
        payment_method=payment.payment_method.value,
        payment_method_other=payment.payment_method_other,
    )


async def pupils_listed(
    db: AsyncSession,
    opening: AccountingOpening,
    tax_code: str | None = None,
) -> list[OpeningPupilResponse]:
    query = select(PupilOpening)

    if tax_code is not None:
        query = query.where(PupilOpening.tax_code == tax_code)

    rows = {row.tax_code: row for row in await db.scalars(query)}
    active = await collaborating(db, list(rows))
    codes = [code for code in rows if code in active]
    people = await _people(db, codes)
    levels = await _levels(db, codes)
    standard = {row.level: row for row in await standard_tariffs(db)}
    tariffs: dict[str, list[StudentTariff]] = defaultdict(list)
    payments: dict[int, list[StudentPayment]] = defaultdict(list)

    if codes:
        for tariff in await db.scalars(
            select(StudentTariff).where(StudentTariff.student_tax_code.in_(codes)),
        ):
            tariffs[tariff.student_tax_code].append(tariff)

        for payment in await db.scalars(
            select(StudentPayment).where(
                StudentPayment.student_tax_code.in_(codes),
                StudentPayment.paid_on < opening.money_from,
                StudentPayment.tariff_id.is_not(None),
            ),
        ):
            payments[payment.tariff_id or 0].append(payment)

    last_day = day_before(opening.money_from)
    listed: list[OpeningPupilResponse] = []

    for code in _sorted(people):
        row = rows[code]
        person = people[code]
        level = levels.get(code)
        of_level = standard.get(level) if level is not None else None
        rates = rates_of(of_level)
        confirmed = row.confirmed_at is not None
        tariff = _in_force(tariffs[code], last_day)
        paid = payments.get(row.tariff_id or 0, []) if confirmed else []
        bought = next(
            (item for item in paid if item.kind != StudentPaymentKindEnum.AHEAD),
            None,
        )
        ahead = next(
            (item for item in paid if item.kind == StudentPaymentKindEnum.AHEAD),
            None,
        )
        total = (
            (tariff.package_hours or 0) * 60
            if tariff is not None and tariff.kind == TariffKindEnum.PACKAGE
            else 0
        )
        ended = confirmed and total > 0 and row.used_minutes >= total

        listed.append(
            OpeningPupilResponse(
                tax_code=code,
                first_name=person.first_name,
                last_name=person.last_name,
                gender=person.gender,
                profile_image_url=person.profile_image_url,
                confirmed=confirmed,
                school_level=level,
                enabled_kinds=sorted(enabled_kinds(of_level)),
                standard=(
                    None
                    if of_level is None
                    else StandardOfLevelResponse(
                        hourly_cents=of_level.hourly_cents,
                        package_cents=of_level.package_cents,
                        package_hours=of_level.package_hours,
                        monthly_cents=of_level.monthly_cents,
                    )
                ),
                settle_cents=rates.settle_cents,
                weekend_online_cents=rates.weekend_online_cents,
                tariff=(
                    None
                    if tariff is None
                    else OpeningTariffResponse(
                        kind=tariff.kind,
                        amount_cents=tariff.amount_cents,
                        package_hours=tariff.package_hours,
                    )
                ),
                payment=None if bought is None else _paid(bought),
                package_ended=ended,
                left_minutes=0 if ended or not total else total - row.used_minutes,
                due_minutes=row.due_minutes,
                ahead=(
                    None
                    if ahead is None
                    else OpeningAheadResponse(
                        minutes=ahead.ahead_minutes or 0,
                        cents_per_hour=ahead.cents_per_hour or 0,
                        payment=_paid(ahead),
                    )
                ),
                weekend_minutes=row.weekend_minutes,
            )
        )

    return listed


async def pupil_listed(
    db: AsyncSession,
    opening: AccountingOpening,
    tax_code: str,
) -> OpeningPupilResponse:
    found = await pupils_listed(db, opening, tax_code)

    if not found:
        raise _not_found(_NOT_LISTED_ERROR.for_request())

    return found[0]


async def confirm_teacher(
    db: AsyncSession,
    opening: AccountingOpening,
    tax_code: str,
    data: TeacherOpeningData,
    admin_tax_code: str,
) -> OpeningTeacherResponse:
    assert_open(opening)
    row = await db.get(TeacherOpening, tax_code)
    staff = await db.get(Staff, tax_code)
    person = await db.get(Person, tax_code)

    if (
        row is None
        or staff is None
        or person is None
        or not await collaborating(db, [tax_code])
    ):
        raise _not_found(_NOT_LISTED_ERROR.for_request())

    month = opening.money_from.replace(day=1)
    terms = (await load_terms(db, tax_code)).of_month(month)

    # A board member stays as they are: only the confirmation is asked.
    if await _can_edit(db, tax_code):
        kind = CollaborationTypeEnum(data.collaboration_type)

        if kind == CollaborationTypeEnum.UNPAID:
            raise _bad_request(_KIND_NOT_CHOSEN_ERROR.for_request())

        paid = kind == CollaborationTypeEnum.PAID

        if paid and data.gross_compensation is None:
            raise _bad_request(_RATE_REQUIRED_ERROR.for_request())

        if paid and data.gross is None:
            raise _bad_request(_GROSS_REQUIRED_ERROR.for_request())

        rate = data.gross_compensation if paid else None

        if terms.collaboration_type != kind or terms.rate != rate:
            await set_terms(db, staff, month, kind, rate)

        row.gross = data.gross if paid else None
    else:
        row.gross = None

    row.confirmed_at = func.now()
    row.confirmed_by_tax_code = admin_tax_code
    await db.flush()
    await db.refresh(row)

    return await _teacher_response(db, opening, row, person)


def _payment(
    tax_code: str,
    data: PaymentData,
    last_day: date,
    **fields: object,
) -> StudentPayment:
    if data.paid_on > last_day:
        raise _bad_request(_late_payment_error(last_day))

    return StudentPayment(
        student_tax_code=tax_code,
        paid_on=data.paid_on,
        payment_method=data.payment_method,
        payment_method_other=(
            data.payment_method_other
            if data.payment_method == PaymentMethodEnum.OTHER
            else None
        ),
        **fields,
    )


def _cents(minutes: int, cents_per_hour: int) -> int:
    return (minutes * cents_per_hour * 2 + 60) // 120


# The rows before money_from give way to the set-up's; a row paid for after it
# stays and takes the set-up's terms.
async def _opening_tariff(
    db: AsyncSession,
    row: PupilOpening,
    data: PupilOpeningData,
    money_from: date,
    starts_on: date,
) -> StudentTariff:
    tax_code = row.tax_code
    rows = list(
        await db.scalars(
            select(StudentTariff).where(StudentTariff.student_tax_code == tax_code),
        )
    )
    before = [row for row in rows if row.starts_on < money_from]
    later = list(
        await db.scalars(
            select(StudentPayment).where(
                StudentPayment.student_tax_code == tax_code,
                StudentPayment.paid_on >= money_from,
                StudentPayment.tariff_id.in_([row.id for row in before]),
            ),
        )
    )
    held = {payment.tariff_id for payment in later}

    if len(held) > 1 or any(
        _PAID_KINDS.get(payment.kind) not in (None, data.kind) for payment in later
    ):
        raise _conflict(_OTHER_TARIFF_PAID_ERROR.for_request())

    kept = next((row for row in before if row.id in held), None)

    # Again, only what the set-up wrote goes: its rows share its transaction's now().
    await db.execute(
        delete(StudentPayment).where(
            StudentPayment.student_tax_code == tax_code,
            StudentPayment.paid_on < money_from,
            *(
                []
                if row.confirmed_at is None
                else [StudentPayment.created_at <= row.confirmed_at]
            ),
        ),
    )

    for row in before:
        if row is not kept:
            await db.delete(row)

    await db.flush()

    if kept is None:
        kept = StudentTariff(student_tax_code=tax_code)
        db.add(kept)

    kept.kind = data.kind
    kept.amount_cents = data.amount_cents
    kept.package_hours = data.package_hours
    kept.starts_on = starts_on
    await db.flush()

    return kept


async def confirm_pupil(
    db: AsyncSession,
    opening: AccountingOpening,
    tax_code: str,
    data: PupilOpeningData,
    admin_tax_code: str,
) -> OpeningPupilResponse:
    assert_open(opening)
    row = await db.get(PupilOpening, tax_code)

    if row is None or not await collaborating(db, [tax_code]):
        raise _not_found(_NOT_LISTED_ERROR.for_request())

    money_from = opening.money_from
    last_day = day_before(money_from)
    level = await school_level(db, tax_code)
    of_level = next(
        (item for item in await standard_tariffs(db) if item.level == level),
        None,
    )
    current = _in_force(
        list(
            await db.scalars(
                select(StudentTariff).where(
                    StudentTariff.student_tax_code == tax_code,
                ),
            )
        ),
        last_day,
    )

    # Whoever has a kind turned off keeps it.
    if data.kind not in enabled_kinds(of_level) and (
        current is None or current.kind != data.kind
    ):
        gender = await PersonRepository(db).gender(tax_code)

        raise _bad_request(_KIND_DISABLED_ERRORS[gender].for_request())

    days = [last_day.replace(day=1)]

    for paid in (data.payment, data.ahead.payment if data.ahead else None):
        if paid is not None:
            if paid.paid_on > last_day:
                raise _bad_request(_late_payment_error(last_day))

            days.append(paid.paid_on)

    tariff = await _opening_tariff(db, row, data, money_from, min(days))
    package = data.kind == TariffKindEnum.PACKAGE
    total = (data.package_hours or 0) * 60

    if data.payment is not None and package:
        db.add(
            _payment(
                tax_code,
                data.payment,
                last_day,
                kind=StudentPaymentKindEnum.PACKAGE,
                tariff_id=tariff.id,
                package_hours=data.package_hours,
                amount_cents=data.amount_cents,
            )
        )
    elif data.payment is not None:
        db.add(
            _payment(
                tax_code,
                data.payment,
                last_day,
                kind=StudentPaymentKindEnum.MONTH,
                tariff_id=tariff.id,
                month=last_day.replace(day=1),
                amount_cents=data.amount_cents,
            )
        )

    if data.ahead is not None:
        db.add(
            _payment(
                tax_code,
                data.ahead.payment,
                last_day,
                kind=StudentPaymentKindEnum.AHEAD,
                tariff_id=tariff.id,
                ahead_minutes=data.ahead.minutes,
                cents_per_hour=data.ahead.cents_per_hour,
                amount_cents=max(
                    _cents(data.ahead.minutes, data.ahead.cents_per_hour),
                    1,
                ),
            )
        )

    row.tariff_id = tariff.id
    row.used_minutes = (
        (total if data.package_ended else total - data.left_minutes) if package else 0
    )
    row.due_minutes = data.due_minutes
    row.weekend_minutes = data.weekend_minutes
    row.confirmed_at = func.now()
    row.confirmed_by_tax_code = admin_tax_code
    await db.flush()
    await db.refresh(row)

    return await pupil_listed(db, opening, tax_code)


async def close_opening(
    db: AsyncSession,
    opening: AccountingOpening,
    admin_tax_code: str,
) -> None:
    assert_open(opening)

    for table in (TeacherOpening, PupilOpening):
        waiting = await db.scalars(
            select(table.tax_code).where(table.confirmed_at.is_(None)),
        )

        if await collaborating(db, list(waiting)):
            raise _conflict(_STILL_PENDING_ERROR.for_request())

    opening.closed_at = func.now()
    opening.closed_by_tax_code = admin_tax_code
    await db.flush()
    await db.refresh(opening)
