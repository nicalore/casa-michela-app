"""Everyone told of a change to the opening hours; a notice may name a day alone

Revision ID: a3d9f6b2c815
Revises: f2c8a4e61b07
Create Date: 2026-10-17
"""

from alembic import op

revision = "a3d9f6b2c815"
down_revision = "f2c8a4e61b07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'OPENING_HOURS_CHANGED'"
        )

    op.drop_constraint(
        op.f("ck_notifications_calendar_date_with_band"),
        "notifications",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_notifications_calendar_band_with_date"),
        "notifications",
        "calendar_band IS NULL OR calendar_date IS NOT NULL",
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.execute("DELETE FROM notifications WHERE kind = 'OPENING_HOURS_CHANGED'")
    op.execute(
        "DELETE FROM muted_notification_kinds WHERE kind = 'OPENING_HOURS_CHANGED'"
    )
    op.drop_constraint(
        op.f("ck_notifications_calendar_band_with_date"),
        "notifications",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_notifications_calendar_date_with_band"),
        "notifications",
        "(calendar_date IS NULL) = (calendar_band IS NULL)",
    )
