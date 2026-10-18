"""Teachers told of availabilities someone else wrote for them; notices of items

Revision ID: a6e8c4f2d735
Revises: f5d7b3e9c124
Create Date: 2026-10-17
"""

from alembic import op

revision = "a6e8c4f2d735"
down_revision = "f5d7b3e9c124"
branch_labels = None
depends_on = None

_KINDS = ("AVAILABILITY_ADDED", "AVAILABILITY_CHANGED", "AVAILABILITY_CANCELLED")


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        for kind in _KINDS:
            op.execute(
                f"ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS '{kind}'"
            )

    # Lessons and availabilities alike, written by a booker or anyone else.
    op.alter_column("notifications", "booking_ids", new_column_name="item_ids")
    op.alter_column(
        "notifications",
        "booker_tax_code",
        new_column_name="author_tax_code",
    )
    op.execute(
        "ALTER TABLE notifications RENAME CONSTRAINT "
        "fk_notifications_booker_tax_code_people "
        "TO fk_notifications_author_tax_code_people"
    )


# Postgres cannot drop an enum value: the rows of the new kinds go instead.
def downgrade() -> None:
    op.execute(
        "ALTER TABLE notifications RENAME CONSTRAINT "
        "fk_notifications_author_tax_code_people "
        "TO fk_notifications_booker_tax_code_people"
    )
    op.alter_column(
        "notifications",
        "author_tax_code",
        new_column_name="booker_tax_code",
    )
    op.alter_column("notifications", "item_ids", new_column_name="booking_ids")
    kinds = ", ".join(f"'{kind}'" for kind in _KINDS)
    op.execute(f"DELETE FROM notifications WHERE kind IN ({kinds})")
    op.execute(f"DELETE FROM muted_notification_kinds WHERE kind IN ({kinds})")
