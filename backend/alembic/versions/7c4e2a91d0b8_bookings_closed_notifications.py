"""Notifications about a calendar band, withdrawn once settled

Revision ID: 7c4e2a91d0b8
Revises: 1b562e0a5a37
Create Date: 2026-10-15
"""

import sqlalchemy as sa

from alembic import op

revision = "7c4e2a91d0b8"
down_revision = "1b562e0a5a37"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum "
            "ADD VALUE IF NOT EXISTS 'BOOKINGS_CLOSED'"
        )

    op.add_column("notifications", sa.Column("calendar_date", sa.Date()))
    op.add_column("notifications", sa.Column("calendar_band", sa.String(20)))
    op.add_column(
        "notifications",
        sa.Column("withdrawn_at", sa.DateTime(timezone=True)),
    )
    op.create_check_constraint(
        op.f("ck_notifications_calendar_band_valid"),
        "notifications",
        "calendar_band IS NULL "
        "OR calendar_band IN ('MORNING', 'AFTERNOON', 'EVENING')",
    )
    op.create_check_constraint(
        op.f("ck_notifications_calendar_date_with_band"),
        "notifications",
        "(calendar_date IS NULL) = (calendar_band IS NULL)",
    )
    op.create_index(
        "uq_notifications_bookings_closed",
        "notifications",
        ["account_tax_code", "calendar_date", "calendar_band"],
        unique=True,
        postgresql_where=sa.text("kind = 'BOOKINGS_CLOSED'"),
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.execute("DELETE FROM notifications WHERE kind = 'BOOKINGS_CLOSED'")
    op.drop_index("uq_notifications_bookings_closed", table_name="notifications")
    op.drop_constraint(
        op.f("ck_notifications_calendar_date_with_band"),
        "notifications",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_notifications_calendar_band_valid"),
        "notifications",
        type_="check",
    )
    op.drop_column("notifications", "withdrawn_at")
    op.drop_column("notifications", "calendar_band")
    op.drop_column("notifications", "calendar_date")
