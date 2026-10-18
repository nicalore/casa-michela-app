"""Devices an account signed in from, so a sign-in from a new one is told

Revision ID: b7f9d5a3e246
Revises: a6e8c4f2d735
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "b7f9d5a3e246"
down_revision = "a6e8c4f2d735"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS 'NEW_DEVICE'"
        )

    op.create_table(
        "known_devices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(length=16), nullable=False),
        sa.Column("key_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "first_seen_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_known_devices_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_known_devices")),
        sa.UniqueConstraint(
            "account_tax_code",
            "key_hash",
            name=op.f("uq_known_devices_account_tax_code"),
        ),
    )
    op.create_index(
        op.f("ix_known_devices_account_tax_code"),
        "known_devices",
        ["account_tax_code"],
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index(op.f("ix_known_devices_account_tax_code"), table_name="known_devices")
    op.drop_table("known_devices")
    op.execute("DELETE FROM notifications WHERE kind = 'NEW_DEVICE'")
    op.execute("DELETE FROM muted_notification_kinds WHERE kind = 'NEW_DEVICE'")
