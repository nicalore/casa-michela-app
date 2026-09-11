"""The medical certificate expiry is optional

Revision ID: c3a7e1f92d05
Revises: e5a3b7c19d24
Create Date: 2026-09-10
"""

import sqlalchemy as sa

from alembic import op

revision = "c3a7e1f92d05"
down_revision = "e5a3b7c19d24"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "course_participants",
        "medical_certificate_expiration",
        existing_type=sa.Date(),
        nullable=True,
    )


def downgrade() -> None:
    # Rows left without a date cannot be guessed back, so they go.
    op.execute(
        "DELETE FROM course_participants WHERE medical_certificate_expiration IS NULL"
    )
    op.alter_column(
        "course_participants",
        "medical_certificate_expiration",
        existing_type=sa.Date(),
        nullable=False,
    )
