"""The 19:00 reminders of tomorrow's availabilities and bookings

Revision ID: f2c8a4e61b07
Revises: e7b1c5d93a20
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "f2c8a4e61b07"
down_revision = "e7b1c5d93a20"
branch_labels = None
depends_on = None

_KINDS = ("AVAILABILITY_REMINDER", "BOOKING_REMINDER")


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        for kind in _KINDS:
            op.execute(
                f"ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS '{kind}'"
            )

    op.create_index(
        "uq_notifications_daily_reminder",
        "notifications",
        ["account_tax_code", "kind", "expires_at"],
        unique=True,
        postgresql_where=sa.text(
            "kind IN ('AVAILABILITY_REMINDER', 'BOOKING_REMINDER')"
        ),
    )


# Postgres cannot drop an enum value: the rows of the new kinds go instead.
def downgrade() -> None:
    op.drop_index("uq_notifications_daily_reminder", table_name="notifications")
    op.execute(
        "DELETE FROM notifications "
        "WHERE kind IN ('AVAILABILITY_REMINDER', 'BOOKING_REMINDER')"
    )
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind IN ('AVAILABILITY_REMINDER', 'BOOKING_REMINDER')"
    )
