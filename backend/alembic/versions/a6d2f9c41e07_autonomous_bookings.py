"""Autonomous bookings

Revision ID: a6d2f9c41e07
Revises: c4e8a1f2d693
Create Date: 2026-10-01
"""

import sqlalchemy as sa

from alembic import op

revision = "a6d2f9c41e07"
down_revision = "c4e8a1f2d693"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "accounts",
        sa.Column(
            "autonomous_bookings",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("accounts", "autonomous_bookings")
