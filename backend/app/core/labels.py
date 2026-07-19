from typing import Final

COLLABORATION_TYPE_LABELS: Final[dict[str, str]] = {
    "VOLUNTEER": "Volontario",
    "PAID": "Retribuito",
    "PCTO": "PCTO",
    "UNPAID": "Non pagato",
}

EDUCATION_LEVEL_LABELS: Final[dict[str, str]] = {
    "PRIMARY_SCHOOL": "Scuola primaria",
    "MIDDLE_SCHOOL": "Scuola secondaria di I grado",
    "HIGH_SCHOOL": "Scuola secondaria di II grado",
}

ROMAN_NUMERAL_BY_GRADE: Final[dict[int, str]] = {
    1: "I",
    2: "II",
    3: "III",
    4: "IV",
    5: "V",
}

# Derived from the table above: the two directions cannot drift apart.
GRADE_BY_ROMAN_NUMERAL: Final[dict[str, int]] = {
    numeral: grade for grade, numeral in ROMAN_NUMERAL_BY_GRADE.items()
}


def education_level_label(level: str) -> str:
    return EDUCATION_LEVEL_LABELS.get(level, level)


def translate_education_level(level: str | None) -> str | None:
    if not level:
        return None

    return education_level_label(level)


def translate_collaboration_type(collaboration_type: str | None) -> str | None:
    if not collaboration_type:
        return None

    return COLLABORATION_TYPE_LABELS.get(collaboration_type, collaboration_type)


def roman_numeral(grade: int) -> str:
    return ROMAN_NUMERAL_BY_GRADE.get(grade, str(grade))