from collections.abc import Sequence
from typing import Any, Final

from app.core.i18n import tr

_FIELD_LABELS: Final[dict[str, tuple[str, str]]] = {
    "admin_data": ("Dati amministratore", "Administrator details"),
    "age_group": ("Fascia d'età", "Age group"),
    "allergies_notes": ("Allergie e intolleranze", "Allergies and intolerances"),
    "area": ("Area", "Area"),
    "assignment": ("Assegnazione", "Assignment"),
    "association_subject_id": ("Disciplina", "Discipline"),
    "association_subject_ids": ("Discipline", "Disciplines"),
    "authorized_early_exit": ("Uscita autonoma", "Leaving unaccompanied"),
    "authorized_pickup": ("Autorizzazione al ritiro", "Pickup authorisation"),
    "availability_id": ("Disponibilità", "Availability"),
    "band": ("Parte della giornata", "Part of the day"),
    "birth_city": ("Città di nascita", "City of birth"),
    "birth_date": ("Data di nascita", "Date of birth"),
    "birth_nation": ("Nazione di nascita", "Country of birth"),
    "birth_province": ("Provincia di nascita", "Province of birth"),
    "booker_tax_code": (
        "Codice fiscale di chi prenota",
        "Tax code of the person booking",
    ),
    "booking_ids": ("Prenotazioni", "Bookings"),
    "capacity": ("Capienza", "Capacity"),
    "certification_dsa_detail": ("Tipo di DSA", "Type of SLD"),
    "certification_other_detail": ("Altra certificazione", "Other certification"),
    "certification_types": ("Tipo di certificazione", "Type of certification"),
    "city": ("Città", "City"),
    "collaborating_active": ("Collaborazione attiva", "Active collaboration"),
    "collaboration_type": ("Tipo di collaborazione", "Type of collaboration"),
    "competences": ("Competenze", "Skills"),
    "consents_signed_at": (
        "Data di firma dei consensi",
        "Date the consents were signed",
    ),
    "cost": ("Costo", "Cost"),
    "course_participant_data": ("Dati corsista", "Course participant details"),
    "course_type": ("Tipo di corso", "Course type"),
    "current_password": ("Password attuale", "Current password"),
    "date": ("Data", "Date"),
    "date_from": ("Data iniziale", "Start date"),
    "date_to": ("Data finale", "End date"),
    "description": ("Descrizione", "Description"),
    "duration": ("Durata", "Duration"),
    "early_exit_end_date": ("Fine dell'uscita anticipata", "End of early departure"),
    "early_exit_schedules": ("Giorni di uscita anticipata", "Early departure days"),
    "early_exit_start_date": (
        "Inizio dell'uscita anticipata",
        "Start of early departure",
    ),
    "effective_from": ("In vigore dal", "In force from"),
    "email": ("Email", "Email"),
    "emergency_contact_name": ("Contatto di emergenza", "Emergency contact"),
    "emergency_contact_phone": (
        "Telefono del contatto di emergenza",
        "Emergency contact phone",
    ),
    "end_date": ("Data di fine", "End date"),
    "end_time": ("Orario di fine", "End time"),
    "enrollments": ("Iscrizioni scolastiche", "School enrolments"),
    "exit_time": ("Orario di uscita", "Leaving time"),
    "expected_updated_at": ("Versione del dato", "Data version"),
    "first_name": ("Nome", "First name"),
    "gender": ("Sesso", "Sex"),
    "general_data": ("Dati anagrafici", "Personal details"),
    "grade": ("Anno di corso", "Year of study"),
    "high_school_track": ("Articolazione", "Track"),
    "homeschooling": ("Istruzione parentale", "Home education"),
    "iban": ("IBAN", "IBAN"),
    "is_high_school_student": ("Studente delle superiori", "Upper secondary student"),
    "language": ("Lingua", "Language"),
    "last_name": ("Cognome", "Surname"),
    "level": ("Livello", "Level"),
    "mandatory_psych_meetings_acknowledged": (
        "Presa d'atto degli incontri con lo psicologo",
        "Acknowledgement of the meetings with the psychologist",
    ),
    "max_year": ("Anno finale", "Last year"),
    "mechanographic_code": ("Codice meccanografico", "School code"),
    "medical_certificate_expiration": (
        "Scadenza del certificato medico",
        "Medical certificate expiry",
    ),
    "medications_notes": ("Farmaci", "Medications"),
    "member_data": ("Dati socio", "Member details"),
    "memberships": ("Tesseramenti", "Memberships"),
    "message": ("Messaggio", "Message"),
    "min_year": ("Anno iniziale", "First year"),
    "ministry_subject_id": ("Materia ministeriale", "Curriculum subject"),
    "ministry_subject_ids": ("Materie ministeriali", "Curriculum subjects"),
    "minors_tax_codes": ("Minori", "Minors"),
    "mode": ("Modalità", "Mode"),
    "modes": ("Modalità", "Modes"),
    "month": ("Mese", "Month"),
    "name": ("Nome", "Name"),
    "new_password": ("Nuova password", "New password"),
    "newsletter_consent": ("Consenso ai notiziari", "Newsletter consent"),
    "note": ("Nota", "Note"),
    "notes": ("Note", "Notes"),
    "other_role": ("Altro ruolo", "Other role"),
    "parent_tax_code": ("Codice fiscale del genitore", "Parent's tax code"),
    "parents_tax_codes": ("Genitori", "Parents"),
    "password": ("Password", "Password"),
    "payment_method": ("Modalità di pagamento", "Payment method"),
    "payment_method_other": ("Altra modalità di pagamento", "Other payment method"),
    "phone": ("Telefono", "Phone"),
    "pickup_restriction_reason": (
        "Motivo della limitazione al ritiro",
        "Reason for the pickup restriction",
    ),
    "postal_code": ("CAP", "Postcode"),
    "preferred_teacher_tax_codes": ("Docenti preferiti", "Preferred teachers"),
    "presence_id": ("Presenza", "Attendance"),
    "province": ("Provincia", "Province"),
    "psychological_support_data": (
        "Dati del supporto psicologico",
        "Psychological support details",
    ),
    "rating": ("Valutazione", "Rating"),
    "reason": ("Motivo", "Reason"),
    "recipients": ("Destinatari", "Recipients"),
    "refresh_token": ("Sessione", "Session"),
    "regulation_acknowledged": (
        "Accettazione del Regolamento",
        "Acceptance of the Regulations",
    ),
    "relationships": ("Relazioni familiari", "Family relationships"),
    "renewal_period_days": ("Giorni di rinnovo", "Renewal days"),
    "residence_address": ("Indirizzo di residenza", "Home address"),
    "residence_city": ("Città di residenza", "City of residence"),
    "residence_province": ("Provincia di residenza", "Province of residence"),
    "residence_street_number": ("Numero civico", "House number"),
    "residence_type": ("Tipo di indirizzo", "Address type"),
    "revocation": ("Revoca", "Revocation"),
    "revocation_type": ("Tipo di revoca", "Revocation type"),
    "role": ("Ruolo", "Role"),
    "roles": ("Ruoli", "Roles"),
    "room_id": ("Aula", "Room"),
    "school_class": ("Classe", "Class"),
    "school_education": ("Studi scolastici", "School education"),
    "school_enrollments": ("Iscrizioni scolastiche", "School enrolments"),
    "school_id": ("Scuola", "School"),
    "sector": ("Settore", "Sector"),
    "service_name": ("Servizio", "Service"),
    "service_names": ("Servizi", "Services"),
    "slots": ("Orari", "Hours"),
    "special_category_data_consent": (
        "Consenso al trattamento dei dati particolari",
        "Consent to the processing of special category data",
    ),
    "staff_data": ("Dati collaboratore", "Collaborator details"),
    "start_date": ("Data di inizio", "Start date"),
    "start_time": ("Orario di inizio", "Start time"),
    "start_year": ("Anno di inizio", "Start year"),
    "statute_acknowledged": (
        "Presa visione dello Statuto",
        "Acknowledgement of the Statute",
    ),
    "student_data": ("Dati studente", "Student details"),
    "student_tax_code": ("Codice fiscale dello studente", "Student's tax code"),
    "study_program_id": ("Indirizzo di studi", "Course of study"),
    "study_program_ids": ("Indirizzi di studi", "Courses of study"),
    "subject_id": ("Materia", "Subject"),
    "subjects": ("Materie", "Subjects"),
    "tags": ("Tipo di lezione", "Lesson type"),
    "tax_code": ("Codice fiscale", "Tax code"),
    "teacher_data": ("Dati docente", "Teacher details"),
    "teacher_tax_code": ("Codice fiscale del docente", "Teacher's tax code"),
    "teacher_tax_codes": ("Docenti", "Teachers"),
    "text": ("Osservazione", "Observation"),
    "title": ("Titolo", "Title"),
    "token": ("Codice di reimpostazione", "Reset code"),
    "topic": ("Argomento", "Topic"),
    "university_education": ("Studi universitari", "University education"),
    "until": ("Fino al", "Until"),
    "video_surveillance_acknowledged": (
        "Consapevolezza della videosorveglianza",
        "Awareness of the video surveillance",
    ),
    "weekday": ("Giorno della settimana", "Day of the week"),
    "weekdays": ("Giorni", "Days"),
    "year": ("Anno", "Year"),
}

_LOCATION_SECTIONS: Final[frozenset[str]] = frozenset(
    {"body", "query", "path", "header", "cookie"}
)

_GENERIC_ERROR: Final[tuple[str, str]] = (
    "I dati inviati non sono validi.",
    "The data sent is not valid.",
)

# Pydantic prefixes validator ValueErrors with this; only the prefix is stripped.
_VALUE_ERROR_PREFIX: Final[str] = "Value error, "

_MOST_SAID: Final[int] = 3

_AND_THE_REST_ERROR: Final[tuple[str, str]] = (
    "C'è un altro campo da correggere.",
    "There is one more field to correct.",
)

_AND_THE_OTHERS_ERROR: Final[tuple[str, str]] = (
    "Ci sono altri {count} campi da correggere.",
    "There are {count} more fields to correct.",
)


def _label(location: tuple[Any, ...]) -> str | None:
    for part in reversed(location):
        if isinstance(part, str) and part not in _LOCATION_SECTIONS:
            label = _FIELD_LABELS.get(part)

            if label is not None:
                return tr(*label)

            return part.replace("_", " ").capitalize()

    return None


def _item_position(location: tuple[Any, ...]) -> int | None:
    for part in reversed(location):
        if isinstance(part, int):
            return part + 1

    return None


def _characters(count: int) -> str:
    if count == 1:
        return tr("1 carattere", "1 character")

    return tr(f"{count} caratteri", f"{count} characters")


def _items(count: int) -> str:
    if count == 1:
        return tr("1 elemento", "1 item")

    return tr(f"{count} elementi", f"{count} items")


def _message_for(error: dict[str, Any], subject: str) -> str:
    kind: str = str(error.get("type", ""))
    context: dict[str, Any] = error.get("ctx") or {}
    given: Any = error.get("input")

    if kind == "missing":
        return tr(f"{subject} è obbligatorio.", f"{subject} is required.")

    if kind == "string_too_long":
        limit = int(context.get("max_length", 0))
        written = len(given) if isinstance(given, str) else 0

        return tr(
            f"{subject} può contenere al massimo {_characters(limit)}: "
            f"ne sono stati inseriti {written}.",
            f"{subject} can contain at most {_characters(limit)}: "
            f"{written} were entered.",
        )

    if kind == "string_too_short":
        minimum = int(context.get("min_length", 0))

        if minimum <= 1:
            return tr(f"{subject} non può essere vuoto.", f"{subject} can't be empty.")

        return tr(
            f"{subject} deve contenere almeno {_characters(minimum)}.",
            f"{subject} must contain at least {_characters(minimum)}.",
        )

    if kind == "too_long":
        limit = int(context.get("max_length", 0))

        return tr(
            f"{subject} può contenere al massimo {_items(limit)}.",
            f"{subject} can contain at most {_items(limit)}.",
        )

    if kind == "too_short":
        minimum = int(context.get("min_length", 0))

        return tr(
            f"{subject} richiede almeno {_items(minimum)}.",
            f"{subject} requires at least {_items(minimum)}.",
        )

    if kind in ("greater_than", "greater_than_equal"):
        bound = context.get("gt", context.get("ge"))
        if kind == "greater_than":
            return tr(
                f"{subject} deve essere maggiore di {bound}.",
                f"{subject} must be greater than {bound}.",
            )

        return tr(
            f"{subject} deve essere almeno {bound}.",
            f"{subject} must be at least {bound}.",
        )

    if kind in ("less_than", "less_than_equal"):
        bound = context.get("lt", context.get("le"))
        if kind == "less_than":
            return tr(
                f"{subject} deve essere minore di {bound}.",
                f"{subject} must be less than {bound}.",
            )

        return tr(
            f"{subject} deve essere al massimo {bound}.",
            f"{subject} must be at most {bound}.",
        )

    if kind == "enum" or kind.endswith("_type") or kind.endswith("_parsing"):
        return tr(
            f"{subject} non è nel formato previsto.",
            f"{subject} is not in the expected format.",
        )

    return tr(f"{subject} non è valido.", f"{subject} is not valid.")


def _hand_written(error: dict[str, Any]) -> str | None:
    if error.get("type") != "value_error":
        return None

    message = str(error.get("msg", ""))

    if message.startswith(_VALUE_ERROR_PREFIX):
        message = message[len(_VALUE_ERROR_PREFIX) :]

    return message or None


def _sentence(error: dict[str, Any]) -> str:
    written = _hand_written(error)

    if written is not None:
        return written

    location = tuple(error.get("loc", ()))
    label = _label(location)

    if label is None:
        return tr(*_GENERIC_ERROR)

    position = _item_position(location)
    subject = tr(f"Il campo «{label}»", f"The “{label}” field")

    if position is not None:
        subject = tr(f"{subject} (voce {position})", f"{subject} (item {position})")

    return _message_for(error, subject)


def humanize_validation_errors(errors: Sequence[dict[str, Any]]) -> str:
    said: list[str] = []

    for error in errors:
        sentence = _sentence(error)

        if sentence not in said:
            said.append(sentence)

    if not said:
        return tr(*_GENERIC_ERROR)

    if len(said) > _MOST_SAID:
        left = len(said) - _MOST_SAID
        said = said[:_MOST_SAID]

        said.append(
            tr(*_AND_THE_REST_ERROR)
            if left == 1
            else tr(*_AND_THE_OTHERS_ERROR).format(count=left)
        )

    return " ".join(said)
