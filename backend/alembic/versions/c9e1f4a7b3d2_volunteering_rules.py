"""volunteering rules

A teacher's rule from a month on, and months counted otherwise with three values.

Revision ID: c9e1f4a7b3d2
Revises: a3f8d2c61e94
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "c9e1f4a7b3d2"
down_revision = "a3f8d2c61e94"
branch_labels = None
depends_on = None

_RULE_VALID = "rule IN ('weekly', 'daily', 'none')"


def _created_at() -> sa.Column:
    return sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        server_default=sa.text("now()"),
        nullable=False,
    )


def upgrade() -> None:
    op.create_table(
        "volunteering_rules",
        sa.Column("staff_tax_code", sa.String(16), primary_key=True),
        sa.Column("starts_on", sa.Date(), primary_key=True),
        sa.Column("rule", sa.String(10), nullable=False),
        _created_at(),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["staff_tax_code"],
            ["staff.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM starts_on) = 1",
            name="volunteering_rule_starts_a_month",
        ),
        sa.CheckConstraint(_RULE_VALID, name="volunteering_rule_valid"),
    )

    op.create_table(
        "volunteering_months",
        sa.Column("teacher_tax_code", sa.String(16), primary_key=True),
        sa.Column("month", sa.Date(), primary_key=True),
        sa.Column("rule", sa.String(10), nullable=False),
        _created_at(),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="volunteering_month_first_day",
        ),
        sa.CheckConstraint(_RULE_VALID, name="volunteering_month_rule_valid"),
    )

    op.execute(
        """
        INSERT INTO volunteering_months (teacher_tax_code, month, rule, created_at)
        SELECT teacher_tax_code, month, 'daily', created_at
        FROM daily_volunteering_months
        """,
    )
    op.drop_table("daily_volunteering_months")


def downgrade() -> None:
    op.create_table(
        "daily_volunteering_months",
        sa.Column("teacher_tax_code", sa.String(16), primary_key=True),
        sa.Column("month", sa.Date(), primary_key=True),
        _created_at(),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="daily_volunteering_first_day",
        ),
    )

    # Only a month counted by the day had a way to be told before.
    op.execute(
        """
        INSERT INTO daily_volunteering_months (teacher_tax_code, month, created_at)
        SELECT teacher_tax_code, month, created_at
        FROM volunteering_months
        WHERE rule = 'daily'
        """,
    )
    op.drop_table("volunteering_months")
    op.drop_table("volunteering_rules")
