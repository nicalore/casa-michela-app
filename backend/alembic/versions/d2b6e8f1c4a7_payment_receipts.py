"""payment receipts

The bank transfer receipt of a teacher's month, uploaded from the monthly summary.

Revision ID: d2b6e8f1c4a7
Revises: d8b3f6a2c915
Create Date: 2026-11-11
"""

import sqlalchemy as sa

from alembic import op

revision = "d2b6e8f1c4a7"
down_revision = "d8b3f6a2c915"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "payment_receipts",
        sa.Column("staff_tax_code", sa.String(16), primary_key=True),
        sa.Column("month", sa.Date(), primary_key=True),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(255), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column(
            "uploaded_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("uploaded_by_tax_code", sa.String(16), nullable=True),
        sa.Column("content", sa.LargeBinary(), nullable=False),
        sa.ForeignKeyConstraint(
            ["staff_tax_code"],
            ["staff.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["uploaded_by_tax_code"],
            ["people.tax_code"],
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="payment_receipt_month_first_day",
        ),
        sa.CheckConstraint("size > 0", name="payment_receipt_not_empty"),
    )


def downgrade() -> None:
    op.drop_table("payment_receipts")
