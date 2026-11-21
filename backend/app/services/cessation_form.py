from collections.abc import Sequence
from datetime import date
from typing import Final

from starlette.concurrency import run_in_threadpool

from app.core.pdf_forms import asset_bytes, fill_acroform, form_field_map
from app.core.storage import (
    CESSATION_FORM_FIELD_MAP,
    CESSATION_FORM_TEMPLATE,
    ENROLLMENT_FORM_FONT,
)
from app.models.collaboration_type import CollaborationTypeEnum
from app.models.member import Member
from app.models.membership import Membership, MembershipRevocationEnum
from app.models.membership_revocation import MembershipRevocation
from app.models.person import BORN_ABROAD_PROVINCE, Person
from app.services.cessation import is_minor_on

_FILE_NAME: Final[str] = "Modulo di cessazione {first_name} {last_name} {day}.pdf"

_GROUND_FIELDS: Final[tuple[tuple[str, str], ...]] = (
    ("ground_breach", "esclusione_motivo_inosservanza"),
    ("ground_conduct", "esclusione_motivo_condotte"),
    ("ground_harm", "esclusione_motivo_danno"),
    ("ground_other", "esclusione_motivo_altro"),
)


async def build_cessation_form(person: Person, membership: Membership) -> bytes:
    """Fill a copy of the template from the revoked membership. Nothing is stored."""
    field_map = form_field_map(CESSATION_FORM_FIELD_MAP)
    values = cessation_form_values(person, membership, checked=field_map.checked)

    return await run_in_threadpool(
        fill_acroform,
        asset_bytes(CESSATION_FORM_TEMPLATE),
        field_map.group_by_page(values),
        font=asset_bytes(ENROLLMENT_FORM_FONT),
    )


def cessation_form_file_name(person: Person, membership: Membership) -> str:
    return _FILE_NAME.format(
        first_name=person.first_name.strip(),
        last_name=person.last_name.strip(),
        day=f"{membership.end_date:%d-%m-%Y}",
    )


def cessation_form_values(
    person: Person,
    membership: Membership,
    *,
    checked: str,
) -> dict[str, str]:
    # The revocation ends the membership on the day it is made.
    day = membership.end_date
    details = membership.revocation_details
    guardian = details.guardian if details is not None else None
    member = person.member_profile
    memberships = member.memberships if member is not None else []
    values: dict[str, str] = {}

    if member is not None:
        values[_qualification(member)] = checked

    _text(values, "data_dichiarazione", _day(day))
    _text(values, "firma_socio_data", _day(day))
    _text(values, "socio_cognome_nome", f"{person.last_name} {person.first_name}")
    _text(values, "socio_luogo_data_nascita", _birth(person))
    _text(values, "socio_codice_fiscale", person.tax_code.upper())
    _text(values, "socio_residenza", _residence(person))
    _text(values, "socio_telefono_email", _contacts(person, guardian, day))
    _text(values, "socio_data_ammissione", _day(_first_start(memberships)))
    _text(values, "socio_ultimo_rinnovo", _day(membership.start_date))

    if guardian is not None:
        _text(values, "tutore_nome", f"{guardian.first_name} {guardian.last_name}")
        _text(values, "tutore_codice_fiscale", guardian.tax_code.upper())

    if membership.revocation == MembershipRevocationEnum.EXPULSION:
        values["causa_esclusione"] = checked

    else:
        values["causa_recesso"] = checked

    if details is not None:
        _details(values, details, day, checked=checked)

    return values


def _details(
    values: dict[str, str],
    details: MembershipRevocation,
    day: date,
    *,
    checked: str,
) -> None:
    if details.protocol_number is not None:
        _text(values, "protocollo_numero", details.protocol_number)
        _text(values, "protocollo_anno", str(day.year))

    _text(values, "socio_numero_tessera", details.card_number)
    _text(values, "recesso_motivazione", details.reason)
    _text(values, "esclusione_data_delibera", _day(details.resolution_date))
    _text(values, "esclusione_numero_verbale", details.minutes_number)
    _text(values, "esclusione_altro_descrizione", details.other_ground)
    _text(values, "esclusione_data_contestazione", _day(details.charged_on))

    for column, field in _GROUND_FIELDS:
        if getattr(details, column):
            values[field] = checked


# One box: founder first, then a volunteer collaborator, else ordinary.
def _qualification(member: Member) -> str:
    staff = member.staff_profile
    volunteer = (
        staff is not None
        and staff.collaboration_type == CollaborationTypeEnum.VOLUNTEER
    )

    if member.founder:
        return "qualifica_fondatore"

    if volunteer:
        return "qualifica_volontario"

    return "qualifica_ordinario"


def _first_start(memberships: Sequence[Membership]) -> date | None:
    return min((row.start_date for row in memberships), default=None)


def _birth(person: Person) -> str | None:
    if person.birth_date is None:
        return None

    born = f"{person.birth_date:%d/%m/%Y}"

    if person.birth_province == BORN_ABROAD_PROVINCE:
        place = person.birth_nation
    elif person.birth_city and person.birth_province:
        place = f"{person.birth_city} ({person.birth_province})"
    else:
        place = person.birth_city

    return f"{place}, {born}" if place else born


def _residence(person: Person) -> str | None:
    street = " ".join(
        part.strip()
        for part in (person.residence_type, person.residence_address)
        if part
    )
    number = (person.residence_street_number or "").strip()
    line = f"{street} {number}".strip()

    town = " ".join(
        part for part in (person.postal_code, person.residence_city) if part
    )

    if town and person.residence_province:
        town = f"{town} ({person.residence_province})"

    return ", ".join(part for part in (line, town) if part) or None


# A minor's form carries the guardian's contacts, as the guardian signs it.
def _contacts(person: Person, guardian: Person | None, day: date) -> str | None:
    minor = is_minor_on(person, day)
    source = guardian if minor and guardian is not None else person
    parts = [part for part in (source.phone, source.email) if part]

    return " / ".join(parts) or None


def _text(values: dict[str, str], field: str, value: str | None) -> None:
    if value is None:
        return

    stripped = value.strip()

    if stripped:
        values[field] = stripped


def _day(value: date | None) -> str | None:
    return f"{value:%d/%m/%Y}" if value is not None else None
