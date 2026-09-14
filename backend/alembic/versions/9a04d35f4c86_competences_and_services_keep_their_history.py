"""Competences and services keep their history

Revision ID: 9a04d35f4c86
Revises: 105e64d74fc6
Create Date: 2026-09-14
"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "9a04d35f4c86"
down_revision = "105e64d74fc6"
branch_labels = None
depends_on = None

# Rows that exist today have always held, as far as the statistics can tell.
_SINCE_FOREVER: Final[str] = "2000-01-01"

# (table, key columns, open-row index name)
_TABLES: Final[tuple[tuple[str, tuple[str, ...], str], ...]] = (
    (
        "teaching_competences",
        ("teacher_tax_code", "association_subject_id", "study_program_id"),
        "ux_teaching_competence_open",
    ),
    (
        "teacher_services",
        ("teacher_tax_code", "service_name"),
        "ux_teacher_service_open",
    ),
)


def upgrade() -> None:
    for table, key, open_index in _TABLES:
        op.add_column(
            table,
            sa.Column(
                "valid_from",
                sa.Date(),
                nullable=False,
                server_default=_SINCE_FOREVER,
            ),
        )
        op.alter_column(table, "valid_from", server_default=None)
        op.add_column(table, sa.Column("valid_to", sa.Date(), nullable=True))

        # The dates join the key: a withdrawn competence may be granted again.
        # teaching_competences lost its key in an old migration, so the drop is
        # conditional and any duplicate that slipped in meanwhile goes first.
        op.execute(f"ALTER TABLE {table} DROP CONSTRAINT IF EXISTS pk_{table}")
        op.execute(
            f"DELETE FROM {table} WHERE ctid NOT IN "
            f"(SELECT min(ctid) FROM {table} GROUP BY {', '.join(key)})"
        )
        op.create_primary_key(op.f(f"pk_{table}"), table, [*key, "valid_from"])

        op.create_check_constraint(
            op.f(f"ck_{table}_validity_ends_after_start"),
            table,
            "valid_to IS NULL OR valid_to > valid_from",
        )
        op.create_index(
            open_index,
            table,
            list(key),
            unique=True,
            postgresql_where=sa.text("valid_to IS NULL"),
        )


# History is lost on the way down: only what holds today survives.
def downgrade() -> None:
    for table, key, open_index in _TABLES:
        op.execute(f"DELETE FROM {table} WHERE valid_to IS NOT NULL")

        op.drop_index(open_index, table_name=table)
        op.drop_constraint(
            op.f(f"ck_{table}_validity_ends_after_start"),
            table,
            type_="check",
        )
        op.execute(f"ALTER TABLE {table} DROP CONSTRAINT IF EXISTS pk_{table}")
        op.create_primary_key(op.f(f"pk_{table}"), table, list(key))

        op.drop_column(table, "valid_to")
        op.drop_column(table, "valid_from")
