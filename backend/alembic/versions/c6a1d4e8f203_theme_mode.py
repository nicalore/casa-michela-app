"""Theme mode

Revision ID: c6a1d4e8f203
Revises: b3e8c5d1f702
Create Date: 2026-11-18
"""

import sqlalchemy as sa

from alembic import op

revision = "c6a1d4e8f203"
down_revision = "b3e8c5d1f702"
branch_labels = None
depends_on = None

_MODES = ("LIGHT", "DARK", "SYSTEM")


def upgrade() -> None:
    sa.Enum(*_MODES, name="theme_mode_enum").create(op.get_bind())

    op.add_column(
        "accounts",
        sa.Column(
            "theme_mode",
            sa.Enum(*_MODES, name="theme_mode_enum"),
            server_default="LIGHT",
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("accounts", "theme_mode")
    sa.Enum(name="theme_mode_enum").drop(op.get_bind())
