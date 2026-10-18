"""Notifications for a published calendar, with the desktop's wording

Revision ID: b5e8c1d40f27
Revises: 9d1f3b7a2c64
Create Date: 2026-10-16
"""

import sqlalchemy as sa

from alembic import op

revision = "b5e8c1d40f27"
down_revision = "9d1f3b7a2c64"
branch_labels = None
depends_on = None

_KINDS = ("CALENDAR_PUBLISHED", "CONVOCATION")


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        for kind in _KINDS:
            op.execute(
                f"ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS '{kind}'"
            )

    op.add_column("notifications", sa.Column("web_body", sa.String(500)))
    op.create_check_constraint(
        op.f("ck_notifications_web_body_not_blank"),
        "notifications",
        "web_body IS NULL OR length(trim(web_body)) > 0",
    )


# Postgres cannot drop an enum value: the rows of the new kinds go instead.
def downgrade() -> None:
    op.execute(
        "DELETE FROM notifications "
        "WHERE kind IN ('CALENDAR_PUBLISHED', 'CONVOCATION')"
    )
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind IN ('CALENDAR_PUBLISHED', 'CONVOCATION')"
    )
    op.drop_constraint(
        op.f("ck_notifications_web_body_not_blank"),
        "notifications",
        type_="check",
    )
    op.drop_column("notifications", "web_body")
