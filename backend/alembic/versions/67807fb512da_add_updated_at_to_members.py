"""add updated_at to members

Revision ID: 67807fb512da
Revises: 1f48d805faae
Create Date: 2026-07-05 16:02:57.765518

"""
from alembic import op
import sqlalchemy as sa

revision = "67807fb512da"
down_revision = "1f48d805faae"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "members",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("members", "updated_at")