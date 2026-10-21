"""Accounts record when they accepted the legal documents

Revision ID: d8f2b6a4c1e7
Revises: c4e8a1d7b5f3
Create Date: 2026-10-21
"""

import sqlalchemy as sa

from alembic import op

revision = "d8f2b6a4c1e7"
down_revision = "c4e8a1d7b5f3"
branch_labels = None
depends_on = None


# No backfill: accounts already inside are asked too, once the switch is on.
def upgrade() -> None:
    op.add_column(
        "accounts",
        sa.Column("terms_accepted_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("accounts", "terms_accepted_at")
