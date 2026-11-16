"""What a staff member was paid, and as what, month by month

Revision ID: c7d2e4f19a36
Revises: e9446a9f7478
Create Date: 2026-11-07
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "c7d2e4f19a36"
down_revision = "e9446a9f7478"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "compensation_terms",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("staff_tax_code", sa.String(16), nullable=False),
        sa.Column("starts_on", sa.Date(), nullable=False),
        sa.Column(
            "collaboration_type",
            postgresql.ENUM(name="collaboration_type_enum", create_type=False),
            nullable=False,
        ),
        sa.Column("gross_compensation", sa.Numeric(10, 2), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM starts_on) = 1",
            name=op.f("ck_compensation_terms_compensation_term_starts_a_month"),
        ),
        sa.CheckConstraint(
            "gross_compensation IS NULL OR gross_compensation >= 0",
            name=op.f("ck_compensation_terms_compensation_term_gross_not_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["staff_tax_code"],
            ["staff.tax_code"],
            name=op.f("fk_compensation_terms_staff_tax_code_staff"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_compensation_terms")),
        sa.UniqueConstraint(
            "staff_tax_code",
            "starts_on",
            name="unique_compensation_term_month",
        ),
    )
    op.create_index(
        op.f("ix_compensation_terms_staff_tax_code"),
        "compensation_terms",
        ["staff_tax_code"],
    )


def downgrade() -> None:
    op.drop_table("compensation_terms")
