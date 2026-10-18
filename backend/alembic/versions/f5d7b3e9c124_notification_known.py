"""What a notification's reader knew before its news, so news undone takes it away

Revision ID: f5d7b3e9c124
Revises: e4c6a2d8b913
Create Date: 2026-10-17
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "f5d7b3e9c124"
down_revision = "e4c6a2d8b913"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notifications",
        sa.Column("known", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("notifications", "known")
