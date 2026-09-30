"""Competence waivers

Revision ID: c4e8a1f2d693
Revises: 3f9c2a7e5b18
Create Date: 2026-09-30
"""

import sqlalchemy as sa

from alembic import op

revision = "c4e8a1f2d693"
down_revision = "3f9c2a7e5b18"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "competence_waivers",
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("booking_id", "teacher_tax_code"),
    )
    op.create_index(
        "ix_competence_waivers_teacher_tax_code",
        "competence_waivers",
        ["teacher_tax_code"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_competence_waivers_teacher_tax_code",
        table_name="competence_waivers",
    )
    op.drop_table("competence_waivers")
