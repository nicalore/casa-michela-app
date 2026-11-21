"""Founding members

Revision ID: 38856c796e61
Revises: b1f317e0d888
Create Date: 2026-11-21
"""

import sqlalchemy as sa

from alembic import op

revision = "38856c796e61"
down_revision = "b1f317e0d888"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "members",
        sa.Column("founder", sa.Boolean(), server_default="false", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("members", "founder")
