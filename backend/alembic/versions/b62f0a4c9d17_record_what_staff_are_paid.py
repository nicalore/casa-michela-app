"""Record what a member of staff is paid

Revision ID: b62f0a4c9d17
Revises: a91c4d7e0f38
Create Date: 2026-09-11
"""

import sqlalchemy as sa

from alembic import op

revision = "b62f0a4c9d17"
down_revision = "a91c4d7e0f38"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Nullable with no backfill: unknown pay is not the same as zero.
    op.add_column(
        "staff",
        sa.Column("gross_compensation", sa.Numeric(10, 2), nullable=True),
    )
    op.create_check_constraint(
        "gross_compensation_not_negative",
        "staff",
        "gross_compensation IS NULL OR gross_compensation >= 0",
    )


def downgrade() -> None:
    op.drop_constraint("gross_compensation_not_negative", "staff", type_="check")
    op.drop_column("staff", "gross_compensation")
