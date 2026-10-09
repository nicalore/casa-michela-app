"""Notice pins

Revision ID: d7e3b1a5c902
Revises: c4f7a2d9e816
Create Date: 2026-10-07
"""

import sqlalchemy as sa

from alembic import op

revision = "d7e3b1a5c902"
down_revision = "c4f7a2d9e816"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notice_pins",
        sa.Column("notice_id", sa.Integer(), nullable=False),
        sa.Column("pinned_by_tax_code", sa.String(16), nullable=False),
        sa.Column(
            "pinned_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("until", sa.Date(), nullable=True),
        sa.ForeignKeyConstraint(
            ["notice_id"],
            ["notices.id"],
            name=op.f("fk_notice_pins_notice_id_notices"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["pinned_by_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_notice_pins_pinned_by_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("notice_id", name=op.f("pk_notice_pins")),
    )
    op.create_index(
        op.f("ix_notice_pins_pinned_by_tax_code"),
        "notice_pins",
        ["pinned_by_tax_code"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_notice_pins_pinned_by_tax_code"),
        table_name="notice_pins",
    )
    op.drop_table("notice_pins")
