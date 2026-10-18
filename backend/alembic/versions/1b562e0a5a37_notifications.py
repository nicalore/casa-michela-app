"""Notifications and push devices

Revision ID: 1b562e0a5a37
Revises: e3b6a9d2c471
Create Date: 2026-10-15
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "1b562e0a5a37"
down_revision = "e3b6a9d2c471"
branch_labels = None
depends_on = None

_KIND = postgresql.ENUM(
    "TEST",
    name="notification_kind_enum",
    create_type=False,
)

_PLATFORM = postgresql.ENUM(
    "WEB",
    "ANDROID",
    "IOS",
    name="push_platform_enum",
    create_type=False,
)


def _account_key(table: str) -> sa.ForeignKeyConstraint:
    return sa.ForeignKeyConstraint(
        ["account_tax_code"],
        ["accounts.tax_code"],
        name=op.f(f"fk_{table}_account_tax_code_accounts"),
        ondelete="CASCADE",
        onupdate="CASCADE",
    )


def _timestamp(name: str) -> sa.Column:
    return sa.Column(
        name,
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        nullable=False,
    )


def upgrade() -> None:
    _KIND.create(op.get_bind(), checkfirst=True)
    _PLATFORM.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column("kind", _KIND, nullable=False),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("body", sa.String(500), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        _timestamp("created_at"),
        sa.CheckConstraint(
            "length(trim(title)) > 0",
            name=op.f("ck_notifications_title_not_blank"),
        ),
        sa.CheckConstraint(
            "length(trim(body)) > 0",
            name=op.f("ck_notifications_body_not_blank"),
        ),
        _account_key("notifications"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notifications")),
    )
    op.create_index(
        op.f("ix_notifications_account_tax_code"),
        "notifications",
        ["account_tax_code"],
    )

    op.create_table(
        "push_devices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column("platform", _PLATFORM, nullable=False),
        sa.Column("address", sa.String(2048), nullable=False),
        sa.Column("p256dh", sa.String(200), nullable=True),
        sa.Column("auth", sa.String(200), nullable=True),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.CheckConstraint(
            "length(trim(address)) > 0",
            name=op.f("ck_push_devices_address_not_blank"),
        ),
        sa.CheckConstraint(
            "platform <> 'WEB' OR (p256dh IS NOT NULL AND auth IS NOT NULL)",
            name=op.f("ck_push_devices_web_keys_present"),
        ),
        _account_key("push_devices"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_push_devices")),
        sa.UniqueConstraint("address", name=op.f("uq_push_devices_address")),
    )
    op.create_index(
        op.f("ix_push_devices_account_tax_code"),
        "push_devices",
        ["account_tax_code"],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_push_devices_account_tax_code"), table_name="push_devices")
    op.drop_table("push_devices")
    op.drop_index(op.f("ix_notifications_account_tax_code"), table_name="notifications")
    op.drop_table("notifications")
    _PLATFORM.drop(op.get_bind(), checkfirst=True)
    _KIND.drop(op.get_bind(), checkfirst=True)
