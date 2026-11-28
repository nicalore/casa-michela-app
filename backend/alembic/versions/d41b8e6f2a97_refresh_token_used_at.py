"""first use of each refresh token pair

Revision ID: d41b8e6f2a97
Revises: c7e2f9a4d318
Create Date: 2026-11-27
"""

import sqlalchemy as sa

from alembic import op

revision = "d41b8e6f2a97"
down_revision = "c7e2f9a4d318"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "refresh_tokens",
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
    )

    # Replaced tokens were presented to be replaced; live ones stay unknown.
    op.execute(
        "UPDATE refresh_tokens SET used_at = revoked_at "
        "WHERE token_type = 'REFRESH' AND revoked_at IS NOT NULL"
    )


def downgrade() -> None:
    op.drop_column("refresh_tokens", "used_at")
