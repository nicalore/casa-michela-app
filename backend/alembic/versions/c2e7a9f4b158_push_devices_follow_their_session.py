"""Push devices follow the sign-in that registered them

Revision ID: c2e7a9f4b158
Revises: b7f9d5a3e246
Create Date: 2026-10-18
"""

import sqlalchemy as sa

from alembic import op

revision = "c2e7a9f4b158"
down_revision = "b7f9d5a3e246"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rows from before name no session; every app registers again at its next start.
    op.execute("DELETE FROM push_devices")
    op.add_column(
        "push_devices",
        sa.Column("session_id", sa.String(length=36), nullable=False),
    )


def downgrade() -> None:
    op.drop_column("push_devices", "session_id")
