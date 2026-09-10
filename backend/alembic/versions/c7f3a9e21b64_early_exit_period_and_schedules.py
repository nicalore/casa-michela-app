"""Spell out when and why a pupil leaves early

Revision ID: c7f3a9e21b64
Revises: b3d81c5f2a47
Create Date: 2026-09-09
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "c7f3a9e21b64"
down_revision = "b3d81c5f2a47"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "students",
        sa.Column("early_exit_start_date", sa.Date(), nullable=True),
    )
    op.add_column(
        "students",
        sa.Column("early_exit_end_date", sa.Date(), nullable=True),
    )
    op.create_check_constraint(
        "early_exit_period_is_whole_or_absent",
        "students",
        "(early_exit_start_date IS NULL) = (early_exit_end_date IS NULL)",
    )
    op.create_check_constraint(
        "early_exit_period_end_after_start",
        "students",
        "early_exit_end_date IS NULL OR early_exit_end_date >= early_exit_start_date",
    )
    op.create_check_constraint(
        "early_exit_period_requires_authorization",
        "students",
        "authorized_early_exit OR early_exit_start_date IS NULL",
    )

    op.create_table(
        "early_exit_schedules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(length=16), nullable=False),
        sa.Column("ordinal", sa.SmallInteger(), nullable=False),
        sa.Column(
            "weekdays",
            postgresql.ARRAY(sa.SmallInteger()),
            nullable=False,
        ),
        sa.Column("exit_time", sa.Time(), nullable=False),
        sa.Column("reason", sa.String(length=255), nullable=False),
        sa.CheckConstraint(
            "id > 0",
            name=op.f("ck_early_exit_schedules_positive_early_exit_schedule_id"),
        ),
        sa.CheckConstraint(
            "ordinal BETWEEN 1 AND 2",
            name=op.f("ck_early_exit_schedules_early_exit_schedule_ordinal_range"),
        ),
        sa.CheckConstraint(
            "cardinality(weekdays) > 0",
            name=op.f("ck_early_exit_schedules_early_exit_schedule_has_a_weekday"),
        ),
        sa.CheckConstraint(
            "weekdays <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::smallint[]",
            name=op.f("ck_early_exit_schedules_early_exit_schedule_weekday_range"),
        ),
        sa.CheckConstraint(
            "exit_time < TIME '19:00'",
            name=op.f("ck_early_exit_schedules_early_exit_schedule_before_closing"),
        ),
        sa.CheckConstraint(
            "length(trim(reason)) > 0",
            name=op.f("ck_early_exit_schedules_reason_not_blank"),
        ),
        sa.CheckConstraint(
            "reason IS NULL OR reason = btrim(reason)",
            name=op.f("ck_early_exit_schedules_reason_no_surrounding_whitespace"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_early_exit_schedules_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_early_exit_schedules")),
        sa.UniqueConstraint(
            "student_tax_code",
            "ordinal",
            name="uq_early_exit_schedules_student_ordinal",
        ),
    )
    op.create_index(
        op.f("ix_early_exit_schedules_student_tax_code"),
        "early_exit_schedules",
        ["student_tax_code"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_early_exit_schedules_student_tax_code"),
        table_name="early_exit_schedules",
    )
    op.drop_table("early_exit_schedules")

    for name in (
        "early_exit_period_requires_authorization",
        "early_exit_period_end_after_start",
        "early_exit_period_is_whole_or_absent",
    ):
        op.drop_constraint(name, "students", type_="check")

    op.drop_column("students", "early_exit_end_date")
    op.drop_column("students", "early_exit_start_date")
