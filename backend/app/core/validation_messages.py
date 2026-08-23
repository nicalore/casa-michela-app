from typing import Any, Final

_FIELD_LABELS: Final[dict[str, str]] = {
    "admin_data": "Dati amministratore",
    "age_group": "Fascia d'età",
    "allergies_notes": "Allergie e intolleranze",
    "area": "Area",
    "association_subject_id": "Disciplina",
    "association_subject_ids": "Discipline",
    "authorized_early_exit": "Uscita autonoma",
    "authorized_pickup": "Autorizzazione al ritiro",
    "availability_id": "Disponibilità",
    "band": "Parte della giornata",
    "birth_city": "Città di nascita",
    "birth_date": "Data di nascita",
    "birth_nation": "Nazione di nascita",
    "birth_province": "Provincia di nascita",
    "booker_tax_code": "Codice fiscale di chi prenota",
    "booking_ids": "Prenotazioni",
    "capacity": "Capienza",
    "certification_other_detail": "Altra certificazione",
    "certification_type": "Tipo di certificazione",
    "city": "Città",
    "collaborating_active": "Collaborazione attiva",
    "collaboration_type": "Tipo di collaborazione",
    "competences": "Competenze",
    "consents_signed_at": "Data di firma dei consensi",
    "course_participant_data": "Dati corsista",
    "course_type": "Tipo di corso",
    "current_password": "Password attuale",
    "date": "Data",
    "date_from": "Data iniziale",
    "date_to": "Data finale",
    "description": "Descrizione",
    "duration": "Durata",
    "effective_from": "In vigore dal",
    "email": "Email",
    "emergency_contact_name": "Contatto di emergenza",
    "emergency_contact_phone": "Telefono del contatto di emergenza",
    "end_date": "Data di fine",
    "end_time": "Orario di fine",
    "enrollments": "Iscrizioni scolastiche",
    "expected_updated_at": "Versione del dato",
    "first_name": "Nome",
    "gender": "Sesso",
    "general_data": "Dati anagrafici",
    "grade": "Anno di corso",
    "iban": "IBAN",
    "last_name": "Cognome",
    "level": "Livello",
    "mandatory_psych_meetings_acknowledged": (
        "Presa d'atto degli incontri con lo psicologo"
    ),
    "max_year": "Anno finale",
    "mechanographic_code": "Codice meccanografico",
    "medical_certificate_expiration": "Scadenza del certificato medico",
    "medications_notes": "Farmaci",
    "member_data": "Dati socio",
    "memberships": "Tesseramenti",
    "min_year": "Anno iniziale",
    "ministry_subject_id": "Materia ministeriale",
    "ministry_subject_ids": "Materie ministeriali",
    "minors_tax_codes": "Minori",
    "mode": "Modalità",
    "modes": "Modalità",
    "month": "Mese",
    "name": "Nome",
    "new_password": "Nuova password",
    "newsletter_consent": "Consenso ai notiziari",
    "not_preferred_teacher_tax_codes": "Docenti non graditi",
    "note": "Nota",
    "notes": "Note",
    "other_role": "Altro ruolo",
    "parent_tax_code": "Codice fiscale del genitore",
    "parents_tax_codes": "Genitori",
    "password": "Password",
    "payment_method": "Modalità di pagamento",
    "payment_method_other": "Altra modalità di pagamento",
    "phone": "Telefono",
    "pickup_restriction_reason": "Motivo della limitazione al ritiro",
    "postal_code": "CAP",
    "preferred_teacher_tax_codes": "Docenti preferiti",
    "presence_id": "Presenza",
    "province": "Provincia",
    "psychological_support_data": "Dati del supporto psicologico",
    "refresh_token": "Sessione",
    "regulation_acknowledged": "Accettazione del Regolamento",
    "relationships": "Relazioni familiari",
    "renewal_period_days": "Giorni di rinnovo",
    "residence_address": "Indirizzo di residenza",
    "residence_city": "Città di residenza",
    "residence_province": "Provincia di residenza",
    "residence_street_number": "Numero civico",
    "residence_type": "Tipo di indirizzo",
    "revocation": "Revoca",
    "revocation_type": "Tipo di revoca",
    "role": "Ruolo",
    "roles": "Ruoli",
    "room_id": "Aula",
    "school_class": "Classe",
    "school_education": "Studi scolastici",
    "school_enrollments": "Iscrizioni scolastiche",
    "school_id": "Scuola",
    "sector": "Settore",
    "service_name": "Servizio",
    "service_names": "Servizi",
    "slots": "Orari",
    "special_category_data_consent": "Consenso al trattamento dei dati particolari",
    "staff_data": "Dati collaboratore",
    "start_date": "Data di inizio",
    "start_time": "Orario di inizio",
    "start_year": "Anno di inizio",
    "statute_acknowledged": "Presa visione dello Statuto",
    "student_data": "Dati studente",
    "student_tax_code": "Codice fiscale dello studente",
    "study_program_id": "Indirizzo di studi",
    "study_program_ids": "Indirizzi di studi",
    "subject_id": "Materia",
    "subjects": "Materie",
    "tags": "Tipo di lezione",
    "tax_code": "Codice fiscale",
    "teacher_data": "Dati docente",
    "teacher_tax_code": "Codice fiscale del docente",
    "token": "Codice di reimpostazione",
    "topic": "Argomento",
    "university_education": "Studi universitari",
    "video_surveillance_acknowledged": "Consapevolezza della videosorveglianza",
    "weekday": "Giorno della settimana",
    "year": "Anno",
}

_LOCATION_SECTIONS: Final[frozenset[str]] = frozenset(
    {"body", "query", "path", "header", "cookie"}
)

_GENERIC_ERROR: Final[str] = "I dati inviati non sono validi."

# Pydantic writes a ValueError raised inside a validator as
# "Value error, <message>". The half after the comma is already an Italian
# sentence of ours, so only the English half is dropped.
_VALUE_ERROR_PREFIX: Final[str] = "Value error, "

_MOST_SAID: Final[int] = 3

_AND_THE_REST_ERROR: Final[str] = "C'è un altro campo da correggere."

_AND_THE_OTHERS_ERROR: Final[str] = "Ci sono altri {count} campi da correggere."


def _label(location: tuple[Any, ...]) -> str | None:
    for part in reversed(location):
        if isinstance(part, str) and part not in _LOCATION_SECTIONS:
            label = _FIELD_LABELS.get(part)

            if label is not None:
                return label

            return part.replace("_", " ").capitalize()

    return None


def _item_position(location: tuple[Any, ...]) -> int | None:
    for part in reversed(location):
        if isinstance(part, int):
            return part + 1

    return None


def _characters(count: int) -> str:
    return "1 carattere" if count == 1 else f"{count} caratteri"


def _items(count: int) -> str:
    return "1 elemento" if count == 1 else f"{count} elementi"


def _message_for(error: dict[str, Any], subject: str) -> str:
    kind: str = str(error.get("type", ""))
    context: dict[str, Any] = error.get("ctx") or {}
    given: Any = error.get("input")

    if kind == "missing":
        return f"{subject} è obbligatorio."

    if kind == "string_too_long":
        limit = int(context.get("max_length", 0))
        written = len(given) if isinstance(given, str) else 0

        return (
            f"{subject} può contenere al massimo {_characters(limit)}: "
            f"ne sono stati inseriti {written}."
        )

    if kind == "string_too_short":
        minimum = int(context.get("min_length", 0))

        if minimum <= 1:
            return f"{subject} non può essere vuoto."

        return f"{subject} deve contenere almeno {_characters(minimum)}."

    if kind == "too_long":
        limit = int(context.get("max_length", 0))

        return f"{subject} può contenere al massimo {_items(limit)}."

    if kind == "too_short":
        minimum = int(context.get("min_length", 0))

        return f"{subject} richiede almeno {_items(minimum)}."

    if kind in ("greater_than", "greater_than_equal"):
        bound = context.get("gt", context.get("ge"))
        comparison = "maggiore di" if kind == "greater_than" else "almeno"

        return f"{subject} deve essere {comparison} {bound}."

    if kind in ("less_than", "less_than_equal"):
        bound = context.get("lt", context.get("le"))
        comparison = "minore di" if kind == "less_than" else "al massimo"

        return f"{subject} deve essere {comparison} {bound}."

    if kind == "enum" or kind.endswith("_type") or kind.endswith("_parsing"):
        return f"{subject} non è nel formato previsto."

    return f"{subject} non è valido."


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
        return _GENERIC_ERROR

    position = _item_position(location)
    subject = f"Il campo «{label}»"

    if position is not None:
        subject = f"{subject} (voce {position})"

    return _message_for(error, subject)


def humanize_validation_errors(errors: list[dict[str, Any]]) -> str:
    said: list[str] = []

    for error in errors:
        sentence = _sentence(error)

        if sentence not in said:
            said.append(sentence)

    if not said:
        return _GENERIC_ERROR

    if len(said) > _MOST_SAID:
        left = len(said) - _MOST_SAID
        said = said[:_MOST_SAID]

        said.append(
            _AND_THE_REST_ERROR
            if left == 1
            else _AND_THE_OTHERS_ERROR.format(count=left)
        )

    return " ".join(said)
