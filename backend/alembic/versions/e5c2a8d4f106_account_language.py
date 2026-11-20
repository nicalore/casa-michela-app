"""Account language

Revision ID: e5c2a8d4f106
Revises: d4b7e2a9c315
Create Date: 2026-11-19
"""

import sqlalchemy as sa

from alembic import op

revision = "e5c2a8d4f106"
down_revision = "d4b7e2a9c315"
branch_labels = None
depends_on = None

# Enum names as SQLAlchemy stores them; the API speaks the values 'it' and 'en'.
_LANGUAGES = ("IT", "EN")


def upgrade() -> None:
    sa.Enum(*_LANGUAGES, name="language_enum").create(op.get_bind())

    op.add_column(
        "accounts",
        sa.Column(
            "language",
            sa.Enum(*_LANGUAGES, name="language_enum"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("accounts", "language")
    sa.Enum(name="language_enum").drop(op.get_bind())
