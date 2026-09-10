"""Renewal runs to 31 January, not 30

Revision ID: e5a3b7c19d24
Revises: b62f0a4c9d17
Create Date: 2026-09-11
"""

from alembic import op

revision = "e5a3b7c19d24"
down_revision = "b62f0a4c9d17"
branch_labels = None
depends_on = None

# Renewal is open until 31 January, so 31 days, not 30. Only rows left on the old
# default move: 0 means revoked and any other value was set by hand.
_OLD = 30
_NEW = 31


def upgrade() -> None:
    op.execute(
        f"UPDATE memberships SET renewal_period_days = {_NEW} "
        f"WHERE renewal_period_days = {_OLD}"
    )


def downgrade() -> None:
    op.execute(
        f"UPDATE memberships SET renewal_period_days = {_OLD} "
        f"WHERE renewal_period_days = {_NEW}"
    )
