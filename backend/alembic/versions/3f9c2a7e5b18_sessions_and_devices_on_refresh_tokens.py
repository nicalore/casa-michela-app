"""Sessions and devices on refresh tokens

Revision ID: 3f9c2a7e5b18
Revises: 70758f833cf4
Create Date: 2026-09-23
"""

import sqlalchemy as sa

from alembic import op

revision = "3f9c2a7e5b18"
down_revision = "70758f833cf4"
branch_labels = None
depends_on = None

_DEVICE_TYPES = ("DESKTOP", "PHONE", "TABLET", "UNKNOWN")


def upgrade() -> None:
    sa.Enum(*_DEVICE_TYPES, name="device_type_enum").create(op.get_bind())

    op.add_column(
        "refresh_tokens",
        sa.Column("session_id", sa.String(36), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("logged_in_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column(
            "device_type",
            sa.Enum(*_DEVICE_TYPES, name="device_type_enum"),
            server_default="UNKNOWN",
            nullable=False,
        ),
    )
    op.add_column(
        "refresh_tokens",
        sa.Column("device_name", sa.String(120), nullable=True),
    )

    # Each existing token becomes a session of its own, dated at its last rotation.
    op.execute(
        "UPDATE refresh_tokens SET session_id = token_id, logged_in_at = created_at"
    )

    op.alter_column("refresh_tokens", "session_id", nullable=False)
    op.alter_column("refresh_tokens", "logged_in_at", nullable=False)
    op.create_index("ix_refresh_tokens_session_id", "refresh_tokens", ["session_id"])


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_session_id", table_name="refresh_tokens")
    op.drop_column("refresh_tokens", "device_name")
    op.drop_column("refresh_tokens", "device_type")
    op.drop_column("refresh_tokens", "logged_in_at")
    op.drop_column("refresh_tokens", "session_id")
    sa.Enum(name="device_type_enum").drop(op.get_bind())
