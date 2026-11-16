"""The daily summary of teachers' hours: corrections, who confirmed, volunteering

Revision ID: b5e9a3c71d28
Revises: e4a7c1d93b58
Create Date: 2026-11-08
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "b5e9a3c71d28"
down_revision = "e4a7c1d93b58"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "confirmed_bands",
        sa.Column(
            "confirmed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.add_column(
        "confirmed_bands",
        sa.Column("confirmed_by_tax_code", sa.String(16), nullable=True),
    )
    op.add_column(
        "confirmed_bands",
        sa.Column(
            "reopened",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.create_foreign_key(
        "confirmed_bands_confirmed_by_tax_code_fkey",
        "confirmed_bands",
        "people",
        ["confirmed_by_tax_code"],
        ["tax_code"],
        ondelete="SET NULL",
        onupdate="CASCADE",
    )

    op.create_table(
        "confirmed_volunteering",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("teacher_tax_code", sa.String(16), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["date", "band"],
            ["confirmed_bands.date", "confirmed_bands.band"],
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "teacher_tax_code",
            "date",
            "band",
            name="unique_confirmed_volunteering",
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name="confirmed_volunteering_end_after_start",
        ),
    )
    op.create_index(
        "ix_confirmed_volunteering_teacher_tax_code",
        "confirmed_volunteering",
        ["teacher_tax_code"],
    )

    op.create_table(
        "hours_corrections",
        sa.Column("date", sa.Date(), primary_key=True),
        sa.Column("band", sa.String(20), primary_key=True),
        sa.Column("teacher_tax_code", sa.String(16), primary_key=True),
        sa.Column("mode", sa.String(20), nullable=False),
        sa.Column("added", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("absent", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("work", postgresql.JSONB(), nullable=True),
        sa.Column(
            "volunteer_set",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
        sa.Column("volunteer_start", sa.Time(), nullable=True),
        sa.Column("volunteer_end", sa.Time(), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="hours_correction_band_valid",
        ),
        sa.CheckConstraint(
            "mode IN ('presence', 'online')",
            name="hours_correction_mode_valid",
        ),
        sa.CheckConstraint(
            "(volunteer_start IS NULL) = (volunteer_end IS NULL)",
            name="hours_correction_volunteer_whole",
        ),
        sa.CheckConstraint(
            "volunteer_end IS NULL OR volunteer_end > volunteer_start",
            name="hours_correction_volunteer_end_after_start",
        ),
    )


def downgrade() -> None:
    op.drop_table("hours_corrections")
    op.drop_index(
        "ix_confirmed_volunteering_teacher_tax_code",
        table_name="confirmed_volunteering",
    )
    op.drop_table("confirmed_volunteering")
    op.drop_constraint(
        "confirmed_bands_confirmed_by_tax_code_fkey",
        "confirmed_bands",
        type_="foreignkey",
    )
    op.drop_column("confirmed_bands", "reopened")
    op.drop_column("confirmed_bands", "confirmed_by_tax_code")
    op.drop_column("confirmed_bands", "confirmed_at")
