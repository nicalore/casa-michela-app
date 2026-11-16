"""Hours an admin has checked, band by band: pay reads them, not the calendar

Revision ID: e4a7c1d93b58
Revises: c7d2e4f19a36
Create Date: 2026-11-07
"""

import sqlalchemy as sa

from alembic import op

revision = "e4a7c1d93b58"
down_revision = "c7d2e4f19a36"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "confirmed_bands",
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f("ck_confirmed_bands_confirmed_band_valid"),
        ),
        sa.PrimaryKeyConstraint("date", "band", name=op.f("pk_confirmed_bands")),
    )

    op.create_table(
        "confirmed_hours",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(16), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_confirmed_hours_confirmed_hours_end_after_start"),
        ),
        sa.ForeignKeyConstraint(
            ["date", "band"],
            ["confirmed_bands.date", "confirmed_bands.band"],
            name=op.f("fk_confirmed_hours_date_confirmed_bands"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_confirmed_hours_teacher_tax_code_teachers"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_confirmed_hours")),
        sa.UniqueConstraint(
            "teacher_tax_code",
            "date",
            "start_time",
            name="unique_confirmed_hours",
        ),
    )
    op.create_index(
        op.f("ix_confirmed_hours_teacher_tax_code"),
        "confirmed_hours",
        ["teacher_tax_code"],
    )


def downgrade() -> None:
    op.drop_table("confirmed_hours")
    op.drop_table("confirmed_bands")
