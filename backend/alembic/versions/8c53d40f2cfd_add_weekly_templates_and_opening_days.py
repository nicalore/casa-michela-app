"""add weekly_templates and opening_days

Revision ID: 8c53d40f2cfd
Revises: 4c63b0f38db1
Create Date: 2026-07-26 00:00:00.000000

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "8c53d40f2cfd"
down_revision = "4c63b0f38db1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "weekly_templates",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("weekday", sa.SmallInteger(), nullable=False),
        sa.Column("mode", sa.String(length=20), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "id > 0", name=op.f("ck_weekly_templates_positive_weekly_template_id")
        ),
        sa.CheckConstraint(
            "weekday BETWEEN 1 AND 7",
            name=op.f("ck_weekly_templates_weekly_template_weekday_range"),
        ),
        sa.CheckConstraint(
            "mode IN ('presence', 'online')",
            name=op.f("ck_weekly_templates_weekly_template_mode_valid"),
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_weekly_templates_weekly_template_end_after_start"),
        ),
        sa.UniqueConstraint(
            "weekday",
            "mode",
            "start_time",
            name="uq_weekly_templates_weekday_mode_start_time",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_weekly_templates")),
    )

    op.create_table(
        "opening_days",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("mode", sa.String(length=20), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column("end_time", sa.Time(), nullable=True),
        sa.Column(
            "is_override",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column("note", sa.Text(), nullable=True),
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
            "id > 0", name=op.f("ck_opening_days_positive_opening_day_id")
        ),
        sa.CheckConstraint(
            "mode IN ('presence', 'online')",
            name=op.f("ck_opening_days_opening_day_mode_valid"),
        ),
        sa.CheckConstraint(
            "(start_time IS NULL AND end_time IS NULL) OR (end_time > start_time)",
            name=op.f("ck_opening_days_opening_day_closed_or_end_after_start"),
        ),
        sa.CheckConstraint(
            "note IS NULL OR length(trim(note)) > 0",
            name=op.f("ck_opening_days_note_not_blank"),
        ),
        sa.CheckConstraint(
            "note IS NULL OR note = btrim(note)",
            name=op.f("ck_opening_days_note_no_surrounding_whitespace"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_opening_days")),
    )
    op.create_index(
        op.f("ix_opening_days_date"), "opening_days", ["date"], unique=False
    )
    op.create_index(
        "ux_opening_day_closure",
        "opening_days",
        ["date", "mode"],
        unique=True,
        postgresql_where=sa.text("start_time IS NULL"),
    )
    op.create_index(
        "ux_opening_day_slot",
        "opening_days",
        ["date", "mode", "start_time"],
        unique=True,
        postgresql_where=sa.text("start_time IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "ux_opening_day_slot",
        table_name="opening_days",
        postgresql_where=sa.text("start_time IS NOT NULL"),
    )
    op.drop_index(
        "ux_opening_day_closure",
        table_name="opening_days",
        postgresql_where=sa.text("start_time IS NULL"),
    )
    op.drop_index(op.f("ix_opening_days_date"), table_name="opening_days")
    op.drop_table("opening_days")

    op.drop_table("weekly_templates")
