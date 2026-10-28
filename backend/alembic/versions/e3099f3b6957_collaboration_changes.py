"""Collaboration changes, so past days are counted with the state they had

Revision ID: e3099f3b6957
Revises: 581e1a6d1733
Create Date: 2026-10-27
"""

import sqlalchemy as sa

from alembic import op

revision = "e3099f3b6957"
down_revision = "581e1a6d1733"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "collaboration_changes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("member_tax_code", sa.String(16), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["member_tax_code"],
            ["members.tax_code"],
            name=op.f("fk_collaboration_changes_member_tax_code_members"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_collaboration_changes")),
    )
    op.create_index(
        op.f("ix_collaboration_changes_member_tax_code"),
        "collaboration_changes",
        ["member_tax_code"],
    )

    # Earlier changes are unknown: today's state stands for the whole past.
    op.execute(
        "INSERT INTO collaboration_changes (member_tax_code, active) "
        "SELECT tax_code, collaborating_active FROM members",
    )


def downgrade() -> None:
    op.drop_table("collaboration_changes")
