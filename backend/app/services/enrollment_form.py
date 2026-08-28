from datetime import date, datetime
from typing import Any, Final
from zoneinfo import ZoneInfo

from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.pdf_forms import (
    asset_bytes,
    enrollment_field_map,
    fill_acroform,
)
from app.core.storage import (
    ENROLLMENT_FORM_FIELD_MAP,
    ENROLLMENT_FORM_FONT,
    ENROLLMENT_FORM_TEMPLATE,
)
from app.models.course_participant import CourseTypeEnum
from app.models.member import PaymentMethodEnum
from app.models.person import GenderEnum
from app.models.staff import CollaborationTypeEnum
from app.models.student import CertificationTypeEnum
from app.repositories.school_repository import SchoolRepository
from app.schemas.enrollment_form import EnrollmentFormRequest
from app.schemas.person_wizard import PersonWizardPayloadBase

# The association signs its forms from its own seat; the wizard has no field
# for it and never will.
_PLACE: Final[str] = "Thiene"

_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_FILE_NAME: Final[str] = "Modulo di iscrizione {first_name} {last_name} {day}.pdf"

_ROLE_PARENT: Final[str] = "GENITORE"
_ROLE_STUDENT: Final[str] = "STUDENTE"

_PARENT_PREFIXES: Final[tuple[str, ...]] = ("genitore1", "genitore2")

_MEMBERSHIP_VOLUNTEER: Final[str] = "adesione_socio_volontario"
_MEMBERSHIP_ENROLLED: Final[str] = "adesione_socio_iscritto"
_MEMBERSHIP_SUPPORTER: Final[str] = "adesione_socio_sostenitore"
_MEMBERSHIP_ORDINARY: Final[str] = "adesione_socio_ordinario"

_CERTIFICATION_FIELDS: Final[dict[str, str]] = {
    CertificationTypeEnum.DSA: "diagnosi_dsa",
    CertificationTypeEnum.BES: "diagnosi_bes",
    CertificationTypeEnum.ADHD: "diagnosi_adhd",
    CertificationTypeEnum.OTHER: "diagnosi_altro",
}

_COURSE_FIELDS: Final[dict[str, str]] = {
    CourseTypeEnum.YOGA: "corso_yoga",
    CourseTypeEnum.PILATES: "corso_pilates",
}

_PAYMENT_FIELDS: Final[dict[str, str]] = {
    PaymentMethodEnum.CASH: "pagamento_contanti",
    PaymentMethodEnum.BANK_TRANSFER: "pagamento_bonifico",
    PaymentMethodEnum.OTHER: "pagamento_altro",
}


async def build_enrollment_form(
    db: AsyncSession,
    request: EnrollmentFormRequest,
) -> bytes:
    """Fill a copy of the template with the wizard's data. Nothing is stored."""
    field_map = enrollment_field_map(ENROLLMENT_FORM_FIELD_MAP)

    values = enrollment_form_values(
        request,
        school_name=await _school_name(db, request.person),
        today=_today(),
        checked=field_map.checked,
    )

    # Embedding the typeface and re-serialising a 900 KB template costs a
    # quarter of a second of pure CPU; off the loop, so one form being built
    # does not stall every other request.
    return await run_in_threadpool(
        fill_acroform,
        asset_bytes(ENROLLMENT_FORM_TEMPLATE),
        field_map.group_by_page(values),
        font=asset_bytes(ENROLLMENT_FORM_FONT),
    )


def enrollment_form_file_name(
    request: EnrollmentFormRequest,
    *,
    today: date | None = None,
) -> str:
    """What the browser calls the form: whose it is and the day it was made."""
    general = request.person.general_data

    return _FILE_NAME.format(
        first_name=general.first_name.strip(),
        last_name=general.last_name.strip(),
        day=f"{today or _today():%d-%m-%Y}",
    )


def _today() -> date:
    # The server may well run UTC, and a form dated the previous day at one in
    # the morning would be wrong on the paper and in its own name.
    return datetime.now(_TIMEZONE).date()


def enrollment_form_values(
    request: EnrollmentFormRequest,
    *,
    school_name: str | None,
    today: date,
    checked: str,
) -> dict[str, str]:
    """Map the wizard's payload onto the template's field names.

    Only non-empty values are returned: a text field left out keeps the
    template's empty value and a checkbox left out keeps its /Off. That is what
    makes zero, one or two parents — and a person with no member data — fall
    out without a branch of their own.
    """
    values: dict[str, str] = {}
    person = request.person

    _identity(values, "socio", person.general_data, checked=checked)
    _schooling(values, person, school_name=school_name)
    _membership_kind(values, person, checked=checked)

    for prefix, parent in zip(_PARENT_PREFIXES, request.parents, strict=False):
        _identity(values, prefix, parent, checked=checked)

    _diagnosis(values, person, checked=checked)
    _services(values, person, checked=checked)
    _member(values, person, checked=checked)

    _text(values, "luogo_data", f"{_PLACE}, {today:%d/%m/%Y}")

    return values


async def _school_name(
    db: AsyncSession,
    person: PersonWizardPayloadBase,
) -> str | None:
    enrollment = _latest_enrollment(person)

    if enrollment is None:
        return None

    return await SchoolRepository(db).get_name(enrollment.school_id)


def _latest_enrollment(person: PersonWizardPayloadBase) -> Any | None:
    # The form has room for one school year, so the current one wins. Ties are
    # impossible: uq_student_school_year forbids them.
    student = person.student_data

    if student is None or not student.school_enrollments:
        return None

    return max(student.school_enrollments, key=lambda row: row.start_year)


def _identity(
    values: dict[str, str],
    prefix: str,
    data: Any,
    *,
    checked: str,
) -> None:
    """The 13 text fields and 2 sex boxes shared by the socio and both parents."""
    _text(values, f"{prefix}_nome", data.first_name)
    _text(values, f"{prefix}_cognome", data.last_name)
    _tick(values, f"{prefix}_sesso_m", data.gender == GenderEnum.M, checked=checked)
    _tick(values, f"{prefix}_sesso_f", data.gender == GenderEnum.F, checked=checked)
    _text(values, f"{prefix}_luogo_nascita", data.birth_city)
    _text(values, f"{prefix}_prov_nascita", _upper(data.birth_province))
    _text(values, f"{prefix}_nazione_nascita", data.birth_nation)
    _text(values, f"{prefix}_data_nascita", _day(data.birth_date))
    _text(
        values,
        f"{prefix}_indirizzo",
        _address_line(
            data.residence_type,
            data.residence_address,
            data.residence_street_number,
        ),
    )
    _text(values, f"{prefix}_comune", data.residence_city)
    _text(values, f"{prefix}_prov_residenza", _upper(data.residence_province))
    _text(values, f"{prefix}_cap", data.postal_code)
    _text(values, f"{prefix}_telefono", data.phone)
    _text(values, f"{prefix}_codice_fiscale", _upper(data.tax_code))
    _text(values, f"{prefix}_email", data.email)


def _schooling(
    values: dict[str, str],
    person: PersonWizardPayloadBase,
    *,
    school_name: str | None,
) -> None:
    enrollment = _latest_enrollment(person)

    if enrollment is None:
        return

    _text(values, "socio_scuola", school_name)
    # The payload already carries the Roman numeral the dropdown wrote; only
    # persistence converts it to a number.
    _text(values, "socio_classe", enrollment.school_class)
    _text(
        values,
        "socio_anno_scolastico",
        f"{enrollment.start_year}/{enrollment.start_year + 1}",
    )


def _membership_kind(
    values: dict[str, str],
    person: PersonWizardPayloadBase,
    *,
    checked: str,
) -> None:
    # Exactly one of the four boxes: volunteering outranks whatever else the
    # person also is, then being a pupil, then being a parent.
    staff = person.staff_data

    if staff is not None and staff.collaboration_type == CollaborationTypeEnum.VOLUNTEER:
        field = _MEMBERSHIP_VOLUNTEER

    elif _ROLE_STUDENT in person.roles:
        field = _MEMBERSHIP_ENROLLED

    elif _ROLE_PARENT in person.roles:
        field = _MEMBERSHIP_SUPPORTER

    else:
        field = _MEMBERSHIP_ORDINARY

    _tick(values, field, True, checked=checked)


def _diagnosis(
    values: dict[str, str],
    person: PersonWizardPayloadBase,
    *,
    checked: str,
) -> None:
    student = person.student_data

    if student is None:
        return

    certification = student.certification_type

    _tick(values, "diagnosi_dichiarazione", certification is not None, checked=checked)

    for kind, field in _CERTIFICATION_FIELDS.items():
        _tick(values, field, certification == kind, checked=checked)

    if certification == CertificationTypeEnum.OTHER:
        _text(values, "diagnosi_altro_testo", student.certification_other_detail)

    # The form has no cell for the DSA detail: it stays in the database, and
    # only the tick reaches the paper.
    _tick(
        values,
        "diagnosi_incontri_psicologo",
        student.mandatory_psych_meetings_acknowledged,
        checked=checked,
    )


def _services(
    values: dict[str, str],
    person: PersonWizardPayloadBase,
    *,
    checked: str,
) -> None:
    _tick(
        values,
        "sostegno_psicologico_adesione",
        person.psychological_support_data is not None,
        checked=checked,
    )

    # Every pupil joins the homework service: it is what being a pupil of the
    # association means, so the wizard has no separate question for it.
    _tick(
        values,
        "aiuto_compiti_adesione",
        _ROLE_STUDENT in person.roles,
        checked=checked,
    )

    course = person.course_participant_data

    if course is None:
        return

    for kind, field in _COURSE_FIELDS.items():
        _tick(values, field, course.course_type == kind, checked=checked)


def _member(
    values: dict[str, str],
    person: PersonWizardPayloadBase,
    *,
    checked: str,
) -> None:
    member = person.member_data

    if member is None:
        return

    for method, field in _PAYMENT_FIELDS.items():
        _tick(values, field, member.payment_method == method, checked=checked)

    if member.payment_method == PaymentMethodEnum.OTHER:
        _text(values, "pagamento_altro_testo", member.payment_method_other)

    _tick(values, "consenso_statuto", member.statute_acknowledged, checked=checked)
    _tick(values, "consenso_regolamento", member.regulation_acknowledged, checked=checked)
    _tick(
        values,
        "consenso_videosorveglianza",
        member.video_surveillance_acknowledged,
        checked=checked,
    )
    _tick(
        values,
        "consenso_dati_particolari",
        member.special_category_data_consent,
        checked=checked,
    )
    _tick(values, "consenso_notiziari", member.newsletter_consent, checked=checked)

    _text(values, "emergenza_contatto", member.emergency_contact_name)
    _text(values, "emergenza_telefono", member.emergency_contact_phone)
    _text(values, "allergie_patologie", member.allergies_notes)
    _text(values, "farmaci_note", member.medications_notes)


def _text(values: dict[str, str], field: str, value: str | None) -> None:
    if value is None:
        return

    stripped = value.strip()

    if stripped:
        values[field] = stripped


def _tick(values: dict[str, str], field: str, on: bool, *, checked: str) -> None:
    if on:
        values[field] = checked


def _upper(value: str | None) -> str | None:
    return value.strip().upper() if value else value


def _day(value: date | None) -> str | None:
    return f"{value:%d/%m/%Y}" if value is not None else None


def _address_line(
    residence_type: str | None,
    address: str | None,
    street_number: str | None,
) -> str:
    # Nothing in the app joins the three parts today: they are always shown
    # apart, so the one-line form the paper wants is defined here.
    street = " ".join(part.strip() for part in (residence_type, address) if part)
    number = street_number.strip() if street_number else ""

    if street and number:
        return f"{street}, {number}"

    return street or number
