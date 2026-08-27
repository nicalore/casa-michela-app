
"""schools: widen mechanographic_code from 20 to 100 characters

Revision ID: 0d17f8e553a3
Revises: aa410838d808

"""
from alembic import op
import sqlalchemy as sa

revision = "0d17f8e553a3"
down_revision = "aa410838d808"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(20),
        type_=sa.String(100),
        existing_nullable=True,
    )


def downgrade() -> None:
    # Fails if codes longer than 20 chars exist: shrinking must not silently truncate.
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(100),
        type_=sa.String(20),
        existing_nullable=True,
    )