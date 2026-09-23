"""Indexes for presence dates and lookups by child

Revision ID: 70758f833cf4
Revises: b7e2d4c91f03
Create Date: 2026-09-22
"""

from alembic import op

revision = "70758f833cf4"
down_revision = "b7e2d4c91f03"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_presences_date", "presences", ["date"])
    op.create_index(
        "ix_parental_responsibilities_child_tax_code",
        "parental_responsibilities",
        ["child_tax_code"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_parental_responsibilities_child_tax_code",
        table_name="parental_responsibilities",
    )
    op.drop_index("ix_presences_date", table_name="presences")
