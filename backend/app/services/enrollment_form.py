from datetime import date, datetime
from typing import Any, Final
from zoneinfo import ZoneInfo

from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.labels import roman_numeral
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
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import GenderEnum, Person
from app.models.staff import CollaborationTypeEnum
from app.models.student import CertificationTypeEnum
from app.repositories.school_repository import SchoolRepository
from app.schemas.enrollment_form import EnrollmentFormParent, EnrollmentFormRequest
from app.schemas.person_wizard import PersonWizardPayloadBase

# Fixed signing place: the association's seat.
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


# Must match the wizard's role codes.
_ROLE_MEMBER: Final[str] = "ASSOCIATO"
_ROLE_TEACHER: Final[str] = "DOCENTE"
_ROLE_ADMIN: Final[str] = "AMMINISTRATORE"
_ROLE_PSYCHOLOGIST: Final[str] = "PSICOLOGO"
_ROLE_COURSE_PARTICIPANT: Final[str] = "CORSISTA"


def request_for_person(person: Person) -> EnrollmentFormRequest:
    """Rebuild the wizard's payload for someone already in the register."""
    member = person.member_profile
    student = member.student_profile if member else None
    staff = member.staff_profile if member else None

    payload: dict[str, Any] = {
        "general_data": _general_data_of(person),
        "roles": _roles_of(person),
        "relationships": {"minors_tax_codes": [], "parents_tax_codes": []},
    }

    if member is not None:
        payload["member_data"] = {
            "memberships": [],
            "payment_method": member.payment_method,
            "payment_method_other": member.payment_method_other,
            "statute_acknowledged": member.statute_acknowledged,
            "regulation_acknowledged": member.regulation_acknowledged,
            "video_surveillance_acknowledged": member.video_surveillance_acknowledged,
            "special_category_data_consent": member.special_category_data_consent,
            "newsletter_consent": member.newsletter_consent,
            "emergency_contact_name": member.emergency_contact_name,
            "emergency_contact_phone": member.emergency_contact_phone,
            "allergies_notes": member.allergies_notes,
            "medications_notes": member.medications_notes,
        }

        if member.psychological_support_profile is not None:
            payload["psychological_support_data"] = {
                "start_date": member.psychological_support_profile.start_date,
            }

        course = member.course_participant_profile

        if course is not None:
            payload["course_participant_data"] = {
                "medical_certificate_expiration": course.medical_certificate_expiration,
                "course_type": course.course_type,
            }

    if staff is not None:
        payload["staff_data"] = {"collaboration_type": staff.collaboration_type}

    if student is not None:
        payload["student_data"] = {
            "authorized_early_exit": student.authorized_early_exit,
            "certification_types": list(student.certification_types),
            "certification_other_detail": student.certification_other_detail,
            "certification_dsa_detail": student.certification_dsa_detail,
            "mandatory_psych_meetings_acknowledged": (
                student.mandatory_psych_meetings_acknowledged
            ),
            "school_enrollments": [
                {
                    "start_year": enrollment.start_year,
                    "school_id": enrollment.school_study_program.school_id,
                    "study_program_id": enrollment.school_study_program.study_program_id,
                    # The payload carries a Roman numeral; the column stores the number.
                    "school_class": roman_numeral(enrollment.grade),
                }
                for enrollment in student.school_enrollments
                if enrollment.school_study_program is not None
            ],
        }

    return EnrollmentFormRequest(
        person=payload,
        # The form has room for two parents.
        parents=[
            _parent_of(relationship)
            for relationship in person.parental_relationships[:2]
        ],
    )


def _general_data_of(person: Person) -> dict[str, Any]:
    return {
        "first_name": person.first_name,
        "last_name": person.last_name,
        "tax_code": person.tax_code,
        "gender": person.gender,
        "birth_date": person.birth_date,
        "birth_city": person.birth_city,
        "birth_nation": person.birth_nation,
        "birth_province": person.birth_province,
        "residence_type": person.residence_type,
        "residence_address": person.residence_address,
        "residence_street_number": person.residence_street_number,
        "residence_city": person.residence_city,
        "residence_province": person.residence_province,
        "postal_code": person.postal_code,
        "email": person.email,
        "phone": person.phone,
    }


def _parent_of(relationship: ParentalResponsibility) -> EnrollmentFormParent:
    return EnrollmentFormParent(**_general_data_of(relationship.parent.person))


def _roles_of(person: Person) -> list[str]:
    roles: list[str] = []

    if person.parent_profile is not None:
        roles.append(_ROLE_PARENT)

    member = person.member_profile

    if member is None:
        return roles

    roles.append(_ROLE_MEMBER)

    if member.student_profile is not None:
        roles.append(_ROLE_STUDENT)

    if member.course_participant_profile is not None:
        roles.append(_ROLE_COURSE_PARTICIPANT)

    staff = member.staff_profile

    if staff is None:
        return roles

    if staff.administrator_profile is not None:
        roles.append(_ROLE_ADMIN)

    if staff.teacher_profile is not None:
        roles.append(_ROLE_TEACHER)

    if staff.psychologist_profile is not None:
        roles.append(_ROLE_PSYCHOLOGIST)

    return roles


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

    # Roughly a quarter second of CPU per form, so keep it off the event loop.
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
    """Download file name for the form."""
    general = request.person.general_data

    return _FILE_NAME.format(
        first_name=general.first_name.strip(),
        last_name=general.last_name.strip(),
        day=f"{today or _today():%d-%m-%Y}",
    )


def _today() -> date:
    # Local Rome date: a UTC server would date the form a day early.
    return datetime.now(_TIMEZONE).date()


def enrollment_form_values(
    request: EnrollmentFormRequest,
    *,
    school_name: str | None,
    today: date,
    checked: str,
) -> dict[str, str]:
    """Map the wizard's payload onto the template's field names, omitting empty values."""
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
    # The form holds one school year, so the latest enrollment wins.
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
    """Identity fields shared by the member and both parents."""
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
    # Exactly one box, by priority: volunteer, then pupil, then parent.
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

    certifications = set(student.certification_types)

    _tick(values, "diagnosi_dichiarazione", bool(certifications), checked=checked)

    for kind, field in _CERTIFICATION_FIELDS.items():
        _tick(values, field, kind in certifications, checked=checked)

    if CertificationTypeEnum.OTHER in certifications:
        _text(values, "diagnosi_altro_testo", student.certification_other_detail)

    # The form has no cell for the DSA detail; only the tick is printed.
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

    # Every pupil is enrolled in the homework service; the wizard never asks.
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
    street = " ".join(part.strip() for part in (residence_type, address) if part)
    number = street_number.strip() if street_number else ""

    if street and number:
        return f"{street}, {number}"

    return street or number
