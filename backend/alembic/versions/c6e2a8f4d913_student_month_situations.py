"""student month situations

Where each pupil stood at the end of a finished month, for the students' monthly
summary.

Revision ID: c6e2a8f4d913
Revises: b8e3f1a6d724
Create Date: 2026-11-14
"""

import sqlalchemy as sa

from alembic import op

revision = "c6e2a8f4d913"
down_revision = "b8e3f1a6d724"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "student_month_situations",
        sa.Column("month", sa.Date(), primary_key=True),
        sa.Column("student_tax_code", sa.String(16), primary_key=True),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("minutes", sa.Integer(), server_default="0", nullable=False),
        sa.Column("due_cents", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "renewal",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="student_month_situation_first_day",
        ),
        sa.CheckConstraint(
            "minutes >= 0 AND due_cents >= 0",
            name="student_month_situation_not_negative",
        ),
    )


def downgrade() -> None:
    op.drop_table("student_month_situations")
