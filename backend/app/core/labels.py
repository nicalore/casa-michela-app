from typing import Final

from app.core.i18n import ENGLISH

MONTH_NAMES: Final[tuple[str, ...]] = (
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
)

ENGLISH_MONTH_NAMES: Final[tuple[str, ...]] = (
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
)

COLLABORATION_TYPE_LABELS: Final[dict[str, str]] = {
    "VOLUNTEER": "Volontario",
    "PAID": "Retribuito",
    "PCTO": "FSL (Ex PCTO)",
    "UNPAID": "Non pagato",
}

_ENGLISH_COLLABORATION_TYPE_LABELS: Final[dict[str, str]] = {
    "VOLUNTEER": "Volunteer",
    "PAID": "Paid",
    "PCTO": "FSL (formerly PCTO)",
    "UNPAID": "Unpaid",
}

EDUCATION_LEVEL_LABELS: Final[dict[str, str]] = {
    "PRIMARY_SCHOOL": "Scuola primaria",
    "MIDDLE_SCHOOL": "Scuola secondaria di I grado",
    "HIGH_SCHOOL": "Scuola secondaria di II grado",
}

_ENGLISH_EDUCATION_LEVEL_LABELS: Final[dict[str, str]] = {
    "PRIMARY_SCHOOL": "Primary school",
    "MIDDLE_SCHOOL": "Lower secondary school",
    "HIGH_SCHOOL": "Upper secondary school",
}

HIGH_SCHOOL_TRACK_LABELS: Final[dict[str, str]] = {
    "BIENNIO": "Biennio",
    "TRIENNIO": "Triennio",
    "OTHER": "Altro",
}

_ENGLISH_HIGH_SCHOOL_TRACK_LABELS: Final[dict[str, str]] = {
    "BIENNIO": "First two years",
    "TRIENNIO": "Last three years",
    "OTHER": "Other",
}

# Shown where a school name goes when the pupil has none; forms keep the Italian.
HOMESCHOOLING_LABEL: Final[str] = "Istruzione parentale"
_ENGLISH_HOMESCHOOLING_LABEL: Final[str] = "Home schooling"

CERTIFICATION_TYPE_LABELS: Final[dict[str, str]] = {
    "DSA": "DSA",
    "BES": "BES",
    "ADHD": "ADHD",
    "OTHER": "Altro",
}

_ENGLISH_CERTIFICATION_TYPE_LABELS: Final[dict[str, str]] = {
    "DSA": "SLD",
    "BES": "SEN",
    "ADHD": "ADHD",
    "OTHER": "Other",
}

NO_CERTIFICATION_LABEL: Final[str] = "Nessuna"
_ENGLISH_NO_CERTIFICATION_LABEL: Final[str] = "None"

BOOKING_TAG_LABELS: Final[dict[str, str]] = {
    "ORAL_TEST": "Preparazione interrogazione",
    "WRITTEN_TEST": "Preparazione verifica",
    "HOMEWORK": "Compiti",
    "ENRICHMENT": "Potenziamento",
    "OUTLINES": "Schemi",
    "EXAM_PREPARATION": "Preparazione esami",
    "CERTIFICATION": "Preparazione certificazione",
    "STUDY": "Studio",
}

_ENGLISH_BOOKING_TAG_LABELS: Final[dict[str, str]] = {
    "ORAL_TEST": "Oral test preparation",
    "WRITTEN_TEST": "Written test preparation",
    "HOMEWORK": "Homework",
    "ENRICHMENT": "Enrichment",
    "OUTLINES": "Outlines",
    "EXAM_PREPARATION": "Exam preparation",
    "CERTIFICATION": "Certification preparation",
    "STUDY": "Study",
}

OPENING_MODE_LABELS: Final[dict[str, str]] = {
    "presence": "in presenza",
    "online": "online",
}

_ENGLISH_OPENING_MODE_LABELS: Final[dict[str, str]] = {
    "presence": "in person",
    "online": "online",
}

# Must mirror frontend/lib/core/utils/role_label_mapper.dart.
ROLE_LABELS: Final[dict[str, str]] = {
    "ADMIN": "Amministratore",
    "TEACHER": "Docente",
    "PSYCHOLOGIST": "Psicologo",
    "STUDENT": "Studente",
    "PARENT": "Genitore",
    "COURSE_PARTICIPANT": "Corsista",
}

_ENGLISH_ROLE_LABELS: Final[dict[str, str]] = {
    "ADMIN": "Administrator",
    "TEACHER": "Teacher",
    "PSYCHOLOGIST": "Psychologist",
    "STUDENT": "Student",
    "PARENT": "Parent",
    "COURSE_PARTICIPANT": "Course participant",
}

# Said of a woman; the other roles read the same for both.
FEMININE_ROLE_LABELS: Final[dict[str, str]] = {
    "ADMIN": "Amministratrice",
    "PSYCHOLOGIST": "Psicologa",
    "STUDENT": "Studentessa",
}

# Must mirror frontend/lib/core/utils/time_bucket.dart.
TIME_BAND_LABELS: Final[dict[str, str]] = {
    "MORNING": "Mattina",
    "AFTERNOON": "Pomeriggio",
    "EVENING": "Sera",
}

_ENGLISH_TIME_BAND_LABELS: Final[dict[str, str]] = {
    "MORNING": "Morning",
    "AFTERNOON": "Afternoon",
    "EVENING": "Evening",
}

# "Le prenotazioni della mattina", "il calendario del pomeriggio".
TIME_BAND_PHRASES: Final[dict[str, str]] = {
    "MORNING": "della mattina",
    "AFTERNOON": "del pomeriggio",
    "EVENING": "della sera",
}

# "The morning bookings", "the afternoon calendar".
_ENGLISH_TIME_BAND_PHRASES: Final[dict[str, str]] = {
    "MORNING": "morning",
    "AFTERNOON": "afternoon",
    "EVENING": "evening",
}

ROMAN_NUMERAL_BY_GRADE: Final[dict[int, str]] = {
    1: "I",
    2: "II",
    3: "III",
    4: "IV",
    5: "V",
}

GRADE_BY_ROMAN_NUMERAL: Final[dict[str, int]] = {
    numeral: grade for grade, numeral in ROMAN_NUMERAL_BY_GRADE.items()
}


# Italian unless English is asked for: these labels also travel as data the app
# matches and sort keys, so a reader's text passes request_language() or theirs.
def is_english(language: str | None = None) -> bool:
    return language == ENGLISH


def _pick(
    language: str | None,
    italian: dict[str, str],
    english: dict[str, str],
) -> dict[str, str]:
    return english if is_english(language) else italian


def _translate(value: str, labels: dict[str, str]) -> str:
    return labels.get(value, value)


def _translate_optional(value: str | None, labels: dict[str, str]) -> str | None:
    if not value:
        return None

    return _translate(value, labels)


def month_name(month: int, language: str | None = None) -> str:
    names = ENGLISH_MONTH_NAMES if is_english(language) else MONTH_NAMES

    return names[month - 1]


def homeschooling_label(language: str | None = None) -> str:
    if is_english(language):
        return _ENGLISH_HOMESCHOOLING_LABEL

    return HOMESCHOOLING_LABEL


def high_school_track_label(track: str, language: str | None = None) -> str:
    return _translate(
        track,
        _pick(
            language,
            HIGH_SCHOOL_TRACK_LABELS,
            _ENGLISH_HIGH_SCHOOL_TRACK_LABELS,
        ),
    )


# OTHER names its years: two such programmes may differ in nothing else.
def high_school_track_short_label(
    track: str | None,
    min_year: int,
    max_year: int,
    language: str | None = None,
) -> str | None:
    if not track:
        return None

    if track == "OTHER":
        if is_english(language):
            return f"Years {min_year}-{max_year}"

        return f"Anni {min_year}-{max_year}"

    return high_school_track_label(track, language)


def education_level_label(level: str, language: str | None = None) -> str:
    return _translate(
        level,
        _pick(language, EDUCATION_LEVEL_LABELS, _ENGLISH_EDUCATION_LEVEL_LABELS),
    )


def translate_education_level(
    level: str | None,
    language: str | None = None,
) -> str | None:
    return _translate_optional(
        level,
        _pick(language, EDUCATION_LEVEL_LABELS, _ENGLISH_EDUCATION_LEVEL_LABELS),
    )


def translate_collaboration_type(
    collaboration_type: str | None,
    language: str | None = None,
) -> str | None:
    return _translate_optional(
        collaboration_type,
        _pick(
            language,
            COLLABORATION_TYPE_LABELS,
            _ENGLISH_COLLABORATION_TYPE_LABELS,
        ),
    )


def certification_type_label(
    certification_type: str | None,
    language: str | None = None,
) -> str:
    english = is_english(language)

    if certification_type is None:
        return _ENGLISH_NO_CERTIFICATION_LABEL if english else NO_CERTIFICATION_LABEL

    return _translate(
        certification_type,
        _ENGLISH_CERTIFICATION_TYPE_LABELS if english else CERTIFICATION_TYPE_LABELS,
    )


def booking_tag_label(tag: str, language: str | None = None) -> str:
    return _translate(
        tag,
        _pick(language, BOOKING_TAG_LABELS, _ENGLISH_BOOKING_TAG_LABELS),
    )


def translate_booking_tag(tag: str | None, language: str | None = None) -> str | None:
    return _translate_optional(
        tag,
        _pick(language, BOOKING_TAG_LABELS, _ENGLISH_BOOKING_TAG_LABELS),
    )


def opening_mode_label(mode: str, language: str | None = None) -> str:
    return _translate(
        mode,
        _pick(language, OPENING_MODE_LABELS, _ENGLISH_OPENING_MODE_LABELS),
    )


def time_band_label(band: str, language: str | None = None) -> str:
    return _translate(
        band,
        _pick(language, TIME_BAND_LABELS, _ENGLISH_TIME_BAND_LABELS),
    )


def time_band_phrase(band: str, language: str | None = None) -> str:
    return _translate(
        band,
        _pick(language, TIME_BAND_PHRASES, _ENGLISH_TIME_BAND_PHRASES),
    )


def role_label(
    role: str,
    *,
    feminine: bool = False,
    language: str | None = None,
) -> str:
    if is_english(language):
        return _translate(role, _ENGLISH_ROLE_LABELS)

    if feminine and role in FEMININE_ROLE_LABELS:
        return FEMININE_ROLE_LABELS[role]

    return _translate(role, ROLE_LABELS)


def roman_numeral(grade: int) -> str:
    return ROMAN_NUMERAL_BY_GRADE.get(grade, str(grade))
