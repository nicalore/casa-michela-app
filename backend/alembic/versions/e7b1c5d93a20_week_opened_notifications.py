"""Friday's notices that next week is open to availabilities and bookings

Revision ID: e7b1c5d93a20
Revises: d4a8e2c6f913
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "e7b1c5d93a20"
down_revision = "d4a8e2c6f913"
branch_labels = None
depends_on = None

_KINDS = ("AVAILABILITY_OPENED", "BOOKINGS_OPENED")


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        for kind in _KINDS:
            op.execute(
                f"ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS '{kind}'"
            )

    op.create_index(
        "uq_notifications_week_opened",
        "notifications",
        ["account_tax_code", "kind", "expires_at"],
        unique=True,
        postgresql_where=sa.text(
            "kind IN ('AVAILABILITY_OPENED', 'BOOKINGS_OPENED')"
        ),
    )


# Postgres cannot drop an enum value: the rows of the new kinds go instead.
def downgrade() -> None:
    op.drop_index("uq_notifications_week_opened", table_name="notifications")
    op.execute(
        "DELETE FROM notifications "
        "WHERE kind IN ('AVAILABILITY_OPENED', 'BOOKINGS_OPENED')"
    )
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind IN ('AVAILABILITY_OPENED', 'BOOKINGS_OPENED')"
    )
