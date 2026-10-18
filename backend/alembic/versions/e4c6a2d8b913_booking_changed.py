"""Lessons someone else changed

Revision ID: e4c6a2d8b913
Revises: d9b3e7f1a426
Create Date: 2026-10-17
"""

from alembic import op

revision = "e4c6a2d8b913"
down_revision = "d9b3e7f1a426"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'BOOKING_CHANGED'"
        )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.execute("DELETE FROM notifications WHERE kind = 'BOOKING_CHANGED'")
    op.execute("DELETE FROM muted_notification_kinds WHERE kind = 'BOOKING_CHANGED'")
