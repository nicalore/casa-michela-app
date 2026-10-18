"""Everyone a notice reaches in the app told of it, until they read it

Revision ID: b5e2d8c4f167
Revises: a3d9f6b2c815
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "b5e2d8c4f167"
down_revision = "a3d9f6b2c815"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'NOTICE_RECEIVED'"
        )

    op.add_column("notifications", sa.Column("notice_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        op.f("fk_notifications_notice_id_notices"),
        "notifications",
        "notices",
        ["notice_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_notifications_notice_id"),
        "notifications",
        ["notice_id"],
    )
    op.create_index(
        "uq_notifications_notice_received",
        "notifications",
        ["account_tax_code", "notice_id"],
        unique=True,
        postgresql_where=sa.text("kind = 'NOTICE_RECEIVED'"),
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index("uq_notifications_notice_received", table_name="notifications")
    op.drop_index(op.f("ix_notifications_notice_id"), table_name="notifications")
    op.drop_constraint(
        op.f("fk_notifications_notice_id_notices"),
        "notifications",
        type_="foreignkey",
    )
    op.drop_column("notifications", "notice_id")
    op.execute("DELETE FROM notifications WHERE kind = 'NOTICE_RECEIVED'")
    op.execute("DELETE FROM muted_notification_kinds WHERE kind = 'NOTICE_RECEIVED'")
