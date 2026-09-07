"""add onboarding_completed_at to accounts

Revision ID: e4b7c02a91f5
Revises: c9f4a1d76b28
Create Date: 2026-08-29
"""

import sqlalchemy as sa

from alembic import op

revision = "e4b7c02a91f5"
down_revision = "c9f4a1d76b28"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Backfilled for the accounts that already exist: the first-access flow is
    # for people arriving now, not for those already inside.
    op.add_column(
        "accounts",
        sa.Column("onboarding_completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.execute("UPDATE accounts SET onboarding_completed_at = created_at")


def downgrade() -> None:
    op.drop_column("accounts", "onboarding_completed_at")
