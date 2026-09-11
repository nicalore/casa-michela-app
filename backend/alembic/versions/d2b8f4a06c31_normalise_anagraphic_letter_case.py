"""Anagraphic text carries one letter case

Revision ID: d2b8f4a06c31
Revises: c3a7e1f92d05
Create Date: 2026-09-10
"""

from collections.abc import Callable

import sqlalchemy as sa

from alembic import op

revision = "d2b8f4a06c31"
down_revision = "c3a7e1f92d05"
branch_labels = None
depends_on = None


# Copied rather than imported: a migration must keep behaving the way it did
# the day it ran, whatever app.core.text_case grows into later.
def _title_case(value: str) -> str:
    characters: list[str] = []
    after_letter = False

    for character in value:
        characters.append(character.lower() if after_letter else character.upper())
        after_letter = character.isalpha()

    return "".join(characters)


def _sentence_case(value: str) -> str:
    return value[:1].upper() + value[1:]


def _upper_case(value: str) -> str:
    return value.upper()


_TITLE_CASE: dict[str, tuple[str, ...]] = {
    "people": (
        "first_name",
        "last_name",
        "birth_city",
        "birth_nation",
        "residence_type",
        "residence_address",
        "residence_city",
    ),
    "members": ("emergency_contact_name",),
}

_UPPER_CASE: dict[str, tuple[str, ...]] = {
    "people": ("residence_street_number",),
}

_SENTENCE_CASE: dict[str, tuple[str, ...]] = {
    "members": ("payment_method_other", "allergies_notes", "medications_notes"),
    "students": ("certification_other_detail", "certification_dsa_detail"),
    "teachers": ("school_education", "university_education"),
    "administrators": ("other_role",),
    "early_exit_schedules": ("reason",),
    "parental_responsibilities": ("pickup_restriction_reason",),
}


# One statement per distinct value, not per row: the register holds far more
# rows than spellings, and no table here has a single-column primary key to
# address the rows by anyway.
def _rewrite(column: str, table: str, shape: Callable[[str], str]) -> None:
    connection = op.get_bind()

    values = connection.execute(
        sa.text(
            f"SELECT DISTINCT {column} AS value FROM {table} "  # noqa: S608
            f"WHERE {column} IS NOT NULL"
        )
    ).scalars()

    for value in values:
        shaped = shape(value)

        if shaped == value:
            continue

        connection.execute(
            sa.text(
                f"UPDATE {table} SET {column} = :shaped WHERE {column} = :value"  # noqa: S608
            ),
            {"shaped": shaped, "value": value},
        )


def upgrade() -> None:
    for shapes, shape in (
        (_TITLE_CASE, _title_case),
        (_UPPER_CASE, _upper_case),
        (_SENTENCE_CASE, _sentence_case),
    ):
        for table, columns in shapes.items():
            for column in columns:
                _rewrite(column, table, shape)


def downgrade() -> None:
    # One-way: what anyone typed before is not recorded anywhere.
    pass
