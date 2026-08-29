from typing import Final

COLLABORATION_TYPE_LABELS: Final[dict[str, str]] = {
    "VOLUNTEER": "Volontario",
    "PAID": "Retribuito",
    "PCTO": "FSL (Ex PCTO)",
    "UNPAID": "Non pagato",
}

EDUCATION_LEVEL_LABELS: Final[dict[str, str]] = {
    "PRIMARY_SCHOOL": "Scuola primaria",
    "MIDDLE_SCHOOL": "Scuola secondaria di I grado",
    "HIGH_SCHOOL": "Scuola secondaria di II grado",
}

HIGH_SCHOOL_TRACK_LABELS: Final[dict[str, str]] = {
    "BIENNIO": "Biennio",
    "TRIENNIO": "Triennio",
    "QUADRIENNALE": "Percorso quadriennale",
}

HIGH_SCHOOL_TRACK_SHORT_LABELS: Final[dict[str, str]] = {
    "BIENNIO": "Biennio",
    "TRIENNIO": "Triennio",
    "QUADRIENNALE": "Quadriennale",
}

CERTIFICATION_TYPE_LABELS: Final[dict[str, str]] = {
    "DSA": "DSA",
    "BES": "BES",
    "ADHD": "ADHD",
    "OTHER": "Altro",
}

NO_CERTIFICATION_LABEL: Final[str] = "Nessuna"

COURSE_TYPE_LABELS: Final[dict[str, str]] = {
    "YOGA": "Yoga",
    "PILATES": "Pilates",
}

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

TEACHER_PREFERENCE_TYPE_LABELS: Final[dict[str, str]] = {
    "PREFERRED": "Preferito",
    "NOT_PREFERRED": "Non preferito",
}

OPENING_MODE_LABELS: Final[dict[str, str]] = {
    "presence": "in presenza",
    "online": "online",
}

# Must mirror frontend/lib/core/utils/time_bucket.dart.
TIME_BAND_LABELS: Final[dict[str, str]] = {
    "MORNING": "Mattina",
    "AFTERNOON": "Pomeriggio",
    "EVENING": "Sera",
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


def _translate(value: str, labels: dict[str, str]) -> str:
    return labels.get(value, value)


def _translate_optional(value: str | None, labels: dict[str, str]) -> str | None:
    if not value:
        return None

    return _translate(value, labels)


def education_level_label(level: str) -> str:
    return _translate(level, EDUCATION_LEVEL_LABELS)


def translate_education_level(level: str | None) -> str | None:
    return _translate_optional(level, EDUCATION_LEVEL_LABELS)


def translate_collaboration_type(collaboration_type: str | None) -> str | None:
    return _translate_optional(collaboration_type, COLLABORATION_TYPE_LABELS)


def certification_type_label(certification_type: str | None) -> str:
    if certification_type is None:
        return NO_CERTIFICATION_LABEL

    return _translate(certification_type, CERTIFICATION_TYPE_LABELS)


def course_type_label(course_type: str) -> str:
    return _translate(course_type, COURSE_TYPE_LABELS)


def translate_course_type(course_type: str | None) -> str | None:
    return _translate_optional(course_type, COURSE_TYPE_LABELS)


def booking_tag_label(tag: str) -> str:
    return _translate(tag, BOOKING_TAG_LABELS)


def translate_booking_tag(tag: str | None) -> str | None:
    return _translate_optional(tag, BOOKING_TAG_LABELS)


def teacher_preference_type_label(preference_type: str) -> str:
    return _translate(preference_type, TEACHER_PREFERENCE_TYPE_LABELS)


def opening_mode_label(mode: str) -> str:
    return _translate(mode, OPENING_MODE_LABELS)


def time_band_label(band: str) -> str:
    return _translate(band, TIME_BAND_LABELS)


def roman_numeral(grade: int) -> str:
    return ROMAN_NUMERAL_BY_GRADE.get(grade, str(grade))
