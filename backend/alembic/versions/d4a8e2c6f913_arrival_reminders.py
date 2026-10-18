"""Teachers' reminder before an in-presence convocation, gone at its start

Revision ID: d4a8e2c6f913
Revises: b5e8c1d40f27
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "d4a8e2c6f913"
down_revision = "b5e8c1d40f27"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'ARRIVAL_REMINDER'"
        )

    op.add_column(
        "notifications",
        sa.Column("expires_at", sa.DateTime(timezone=True)),
    )
    op.create_index(
        "uq_notifications_arrival_reminder",
        "notifications",
        ["account_tax_code", "calendar_date", "calendar_band"],
        unique=True,
        postgresql_where=sa.text("kind = 'ARRIVAL_REMINDER'"),
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index("uq_notifications_arrival_reminder", table_name="notifications")
    op.execute("DELETE FROM notifications WHERE kind = 'ARRIVAL_REMINDER'")
    op.execute(
        "DELETE FROM muted_notification_kinds WHERE kind = 'ARRIVAL_REMINDER'"
    )
    op.drop_column("notifications", "expires_at")
