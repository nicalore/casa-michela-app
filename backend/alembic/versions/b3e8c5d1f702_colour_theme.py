"""Colour theme

Revision ID: b3e8c5d1f702
Revises: a7d3f9c2e481
Create Date: 2026-11-17
"""

import sqlalchemy as sa

from alembic import op

revision = "b3e8c5d1f702"
down_revision = "a7d3f9c2e481"
branch_labels = None
depends_on = None

_THEMES = ("CASA_MICHELA", "COBALTO", "ARDESIA", "LAVANDA", "CONFETTO", "TERRACOTTA")


def upgrade() -> None:
    sa.Enum(*_THEMES, name="colour_theme_enum").create(op.get_bind())

    op.add_column(
        "accounts",
        sa.Column(
            "colour_theme",
            sa.Enum(*_THEMES, name="colour_theme_enum"),
            server_default="CASA_MICHELA",
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("accounts", "colour_theme")
    sa.Enum(name="colour_theme_enum").drop(op.get_bind())
