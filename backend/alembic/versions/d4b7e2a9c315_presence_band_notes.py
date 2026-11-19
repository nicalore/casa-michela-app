"""Presence band notes

Revision ID: d4b7e2a9c315
Revises: c6a1d4e8f203
Create Date: 2026-11-19
"""

import sqlalchemy as sa

from alembic import op

revision = "d4b7e2a9c315"
down_revision = "c6a1d4e8f203"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("presences", sa.Column("notes", sa.String(1000), nullable=True))
    op.create_check_constraint(
        op.f("ck_presences_notes_not_blank"),
        "presences",
        "notes IS NULL OR length(trim(notes)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_presences_notes_no_surrounding_whitespace"),
        "presences",
        "notes IS NULL OR notes = btrim(notes)",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_presences_notes_no_surrounding_whitespace"),
        "presences",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_presences_notes_not_blank"),
        "presences",
        type_="check",
    )
    op.drop_column("presences", "notes")
