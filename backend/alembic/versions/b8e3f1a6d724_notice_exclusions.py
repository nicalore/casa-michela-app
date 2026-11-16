"""Teachers and students a notice left out for not collaborating

Revision ID: b8e3f1a6d724
Revises: a7d4e2c9f513
Create Date: 2026-11-13
"""

import sqlalchemy as sa

from alembic import op

revision = "b8e3f1a6d724"
down_revision = "a7d4e2c9f513"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notice_exclusions",
        sa.Column("notice_id", sa.Integer(), nullable=False),
        sa.Column("tax_code", sa.String(16), nullable=False),
        sa.ForeignKeyConstraint(
            ["notice_id"],
            ["notices.id"],
            name=op.f("fk_notice_exclusions_notice_id_notices"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["tax_code"],
            ["people.tax_code"],
            name=op.f("fk_notice_exclusions_tax_code_people"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "notice_id",
            "tax_code",
            name=op.f("pk_notice_exclusions"),
        ),
    )
    op.create_index(
        op.f("ix_notice_exclusions_tax_code"),
        "notice_exclusions",
        ["tax_code"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_notice_exclusions_tax_code"),
        table_name="notice_exclusions",
    )
    op.drop_table("notice_exclusions")
