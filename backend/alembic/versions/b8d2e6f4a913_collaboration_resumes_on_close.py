"""Collaboration resumes on close

Revision ID: b8d2e6f4a913
Revises: f1a8c3d5e702
Create Date: 2026-10-07
"""

import sqlalchemy as sa

from alembic import op

revision = "b8d2e6f4a913"
down_revision = "f1a8c3d5e702"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "members",
        sa.Column(
            "collaboration_paused_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    # Hours already there never bring anybody back.
    op.execute(
        "UPDATE members SET collaboration_paused_at = now() "
        "WHERE NOT collaborating_active",
    )


def downgrade() -> None:
    op.drop_column("members", "collaboration_paused_at")
