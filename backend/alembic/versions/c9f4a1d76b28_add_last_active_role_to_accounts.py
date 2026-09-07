"""add last_active_role to accounts

Revision ID: c9f4a1d76b28
Revises: b8e2c1a47f3d
Create Date: 2026-08-29
"""

import sqlalchemy as sa

from alembic import op

revision = "c9f4a1d76b28"
down_revision = "b8e2c1a47f3d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # No backfill: NULL means "never picked one", which is exactly how every
    # existing account should behave on its next login.
    op.add_column(
        "accounts",
        sa.Column("last_active_role", sa.String(length=30), nullable=True),
    )

    op.create_check_constraint(
        op.f("ck_accounts_last_active_role_not_blank"),
        "accounts",
        "last_active_role IS NULL OR length(trim(last_active_role)) > 0",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_accounts_last_active_role_not_blank"),
        "accounts",
        type_="check",
    )
    op.drop_column("accounts", "last_active_role")
