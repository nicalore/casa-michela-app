"""add effective_from to weekly_templates

Revision ID: c4d81a55e903
Revises: b7e2c4a91f30
Create Date: 2026-07-26

"""

import sqlalchemy as sa
from alembic import op

revision = "c4d81a55e903"
down_revision = "b7e2c4a91f30"
branch_labels = None
depends_on = None

# The association's founding date: existing rows have no recorded start, and
# treating them as effective since forever preserves generation behavior.
_BACKFILL = "2023-01-09"


def upgrade() -> None:
    op.add_column(
        "weekly_templates",
        sa.Column("effective_from", sa.Date(), nullable=True),
    )
    op.execute(
        f"UPDATE weekly_templates SET effective_from = '{_BACKFILL}'::date "
        "WHERE effective_from IS NULL"
    )
    op.alter_column("weekly_templates", "effective_from", nullable=False)


def downgrade() -> None:
    op.drop_column("weekly_templates", "effective_from")
