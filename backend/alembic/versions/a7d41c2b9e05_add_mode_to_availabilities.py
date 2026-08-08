"""add mode to availabilities

Revision ID: a7d41c2b9e05
Revises: d3f7a2b81c45
Create Date: 2026-08-02 11:20:00.000000

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "a7d41c2b9e05"
down_revision = "d3f7a2b81c45"
branch_labels = None
depends_on = None

_DEFAULT_MODE = "presence"


def upgrade() -> None:
    # Everything written before this column existed was offered in the building:
    # online availability had no way of being said, so nothing stored is it.
    op.add_column(
        "availabilities",
        sa.Column("mode", sa.String(length=20), nullable=False, server_default=_DEFAULT_MODE),
    )
    op.alter_column("availabilities", "mode", server_default=None)

    op.create_check_constraint(
        op.f("ck_availabilities_availability_mode_valid"),
        "availabilities",
        "mode IN ('presence', 'online')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_availabilities_availability_mode_valid"),
        "availabilities",
        type_="check",
    )
    op.drop_column("availabilities", "mode")
