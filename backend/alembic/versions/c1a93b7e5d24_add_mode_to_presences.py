"""add mode to presences

Revision ID: c1a93b7e5d24
Revises: b8e52d3caf16
Create Date: 2026-08-03 17:40:00.000000

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "c1a93b7e5d24"
down_revision = "b8e52d3caf16"
branch_labels = None
depends_on = None

_DEFAULT_MODE = "presence"


def upgrade() -> None:
    # Rows predating this column were necessarily in-person: online presence
    # had no way of being recorded.
    op.add_column(
        "presences",
        sa.Column("mode", sa.String(length=20), nullable=False, server_default=_DEFAULT_MODE),
    )
    op.alter_column("presences", "mode", server_default=None)

    op.create_check_constraint(
        op.f("ck_presences_presence_mode_valid"),
        "presences",
        "mode IN ('presence', 'online')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_presences_presence_mode_valid"),
        "presences",
        type_="check",
    )

    op.drop_column("presences", "mode")
