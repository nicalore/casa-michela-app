"""a reset link before the first sign-in sets the password, so no change is pending

Revision ID: bf3ce80cf8c8
Revises: f4b7c2e9a816
Create Date: 2026-10-31
"""

from alembic import op

revision = "bf3ce80cf8c8"
down_revision = "f4b7c2e9a816"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(
        op.f("ck_accounts_first_login_requires_password_reset"),
        "accounts",
        type_="check",
    )


def downgrade() -> None:
    # Accounts reset before their first sign-in would break the old rule.
    op.execute(
        "UPDATE accounts SET password_reset_required = TRUE "
        "WHERE last_login IS NULL"
    )
    op.create_check_constraint(
        op.f("ck_accounts_first_login_requires_password_reset"),
        "accounts",
        "last_login IS NOT NULL OR password_reset_required = TRUE",
    )
