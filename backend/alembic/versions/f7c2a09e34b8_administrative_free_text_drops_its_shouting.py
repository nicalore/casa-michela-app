"""Administrative free text drops its shouting

Revision ID: f7c2a09e34b8
Revises: d2b8f4a06c31
Create Date: 2026-09-10
"""

import sqlalchemy as sa

from alembic import op

revision = "f7c2a09e34b8"
down_revision = "d2b8f4a06c31"
branch_labels = None
depends_on = None


# d2b8f4a06c31 gave every free-text column its opening capital and left the
# rest alone, which reads badly on the short administrative lines: a method of
# payment typed as "CARTA dI CREDIto" stayed that way. Those lines carry no
# acronym worth keeping, so they take the full sentence case. The columns that
# do carry one are left as that migration set them: the notes, where DSA and
# Ventolin survive, and the administrator role, where the department does.
def _sentence_case(value: str) -> str:
    return value[:1].upper() + value[1:].lower()


_COLUMNS: dict[str, tuple[str, ...]] = {
    "members": ("payment_method_other",),
    "teachers": ("school_education", "university_education"),
    "early_exit_schedules": ("reason",),
    "parental_responsibilities": ("pickup_restriction_reason",),
}


# One statement per distinct value, not per row: the register holds far more
# rows than spellings, and no table here has a single-column primary key to
# address the rows by anyway.
def _rewrite(column: str, table: str) -> None:
    connection = op.get_bind()

    values = connection.execute(
        sa.text(
            f"SELECT DISTINCT {column} AS value FROM {table} "  # noqa: S608
            f"WHERE {column} IS NOT NULL"
        )
    ).scalars()

    for value in values:
        shaped = _sentence_case(value)

        if shaped == value:
            continue

        connection.execute(
            sa.text(
                f"UPDATE {table} SET {column} = :shaped WHERE {column} = :value"  # noqa: S608
            ),
            {"shaped": shaped, "value": value},
        )


def upgrade() -> None:
    for table, columns in _COLUMNS.items():
        for column in columns:
            _rewrite(column, table)


def downgrade() -> None:
    # One-way: what anyone typed before is not recorded anywhere.
    pass
