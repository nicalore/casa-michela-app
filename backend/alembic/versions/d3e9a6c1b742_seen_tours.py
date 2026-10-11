"""Seen tutorial tours

Revision ID: d3e9a6c1b742
Revises: fb8fa4a604f6
Create Date: 2026-10-11
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "d3e9a6c1b742"
down_revision = "fb8fa4a604f6"
branch_labels = None
depends_on = None

_PLATFORM = postgresql.ENUM(
    "MOBILE",
    "DESKTOP",
    name="tour_platform_enum",
    create_type=False,
)


def upgrade() -> None:
    _PLATFORM.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "seen_tours",
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column("platform", _PLATFORM, nullable=False),
        sa.Column("slug", sa.String(120), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(slug)) > 0",
            name=op.f("ck_seen_tours_slug_not_blank"),
        ),
        sa.CheckConstraint(
            "version > 0",
            name=op.f("ck_seen_tours_version_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_seen_tours_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "account_tax_code",
            "platform",
            "slug",
            name=op.f("pk_seen_tours"),
        ),
    )


def downgrade() -> None:
    op.drop_table("seen_tours")
    _PLATFORM.drop(op.get_bind(), checkfirst=True)
