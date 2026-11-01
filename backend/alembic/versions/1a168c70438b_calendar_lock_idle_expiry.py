"""a calendar band is let go five minutes after its last change

Revision ID: 1a168c70438b
Revises: bf3ce80cf8c8
Create Date: 2026-11-01
"""

import sqlalchemy as sa

from alembic import op

revision = "1a168c70438b"
down_revision = "bf3ce80cf8c8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "calendar_band_locks",
        sa.Column(
            "written_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("calendar_band_locks", "written_at")
