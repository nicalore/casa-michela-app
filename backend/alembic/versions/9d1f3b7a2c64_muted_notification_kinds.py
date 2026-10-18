"""Notification kinds each account turned off

Revision ID: 9d1f3b7a2c64
Revises: 7c4e2a91d0b8
Create Date: 2026-10-16
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "9d1f3b7a2c64"
down_revision = "7c4e2a91d0b8"
branch_labels = None
depends_on = None

_KIND = postgresql.ENUM(name="notification_kind_enum", create_type=False)


def upgrade() -> None:
    op.create_table(
        "muted_notification_kinds",
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column("kind", _KIND, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_muted_notification_kinds_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "account_tax_code",
            "kind",
            name=op.f("pk_muted_notification_kinds"),
        ),
    )


def downgrade() -> None:
    op.drop_table("muted_notification_kinds")
