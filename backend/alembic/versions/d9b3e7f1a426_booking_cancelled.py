"""Lessons someone else cancelled, and the lessons each booking notice tells of

Revision ID: d9b3e7f1a426
Revises: c8a1f5e3d294
Create Date: 2026-10-17
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "d9b3e7f1a426"
down_revision = "c8a1f5e3d294"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'BOOKING_CANCELLED'"
        )

    op.add_column(
        "notifications",
        sa.Column("booking_ids", postgresql.ARRAY(sa.Integer()), nullable=True),
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_column("notifications", "booking_ids")
    op.execute("DELETE FROM notifications WHERE kind = 'BOOKING_CANCELLED'")
    op.execute(
        "DELETE FROM muted_notification_kinds WHERE kind = 'BOOKING_CANCELLED'"
    )
