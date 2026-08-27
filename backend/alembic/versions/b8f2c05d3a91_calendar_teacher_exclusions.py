"""add per-band teacher exclusions from a calendar

Revision ID: b8f2c05d3a91
Revises: a3d59f21c4b7
Create Date: 2026-08-27

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "b8f2c05d3a91"
down_revision = "a3d59f21c4b7"
branch_labels = None
depends_on = None

_EXCLUSIONS: Final[str] = "calendar_teacher_exclusions"

_BAND_LENGTH: Final[int] = 20

_BAND_INDEX: Final[str] = "ix_calendar_teacher_exclusion_band"

_BAND_CHECK: Final[str] = "calendar_teacher_exclusion_band_valid"


def upgrade() -> None:
    op.create_table(
        _EXCLUSIONS,
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(length=_BAND_LENGTH), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f(f"fk_{_EXCLUSIONS}_teacher_tax_code_teachers"),
            # tax_code is a mutable natural key.
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f(f"ck_{_EXCLUSIONS}_{_BAND_CHECK}"),
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "band",
            "teacher_tax_code",
            name=op.f(f"pk_{_EXCLUSIONS}"),
        ),
    )

    op.create_index(_BAND_INDEX, _EXCLUSIONS, ["date", "band"])


def downgrade() -> None:
    op.drop_index(_BAND_INDEX, table_name=_EXCLUSIONS)
    op.drop_table(_EXCLUSIONS)
