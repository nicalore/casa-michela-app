"""Parents and pupils told of the lessons someone else booked for the pupil

Revision ID: c8a1f5e3d294
Revises: b5e2d8c4f167
Create Date: 2026-10-17
"""

import sqlalchemy as sa

from alembic import op

revision = "c8a1f5e3d294"
down_revision = "b5e2d8c4f167"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'BOOKING_ADDED'"
        )

    for column in ("pupil_tax_code", "booker_tax_code"):
        op.add_column(
            "notifications",
            sa.Column(column, sa.String(length=16), nullable=True),
        )
        op.create_foreign_key(
            op.f(f"fk_notifications_{column}_people"),
            "notifications",
            "people",
            [column],
            ["tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        )

    op.create_index(
        op.f("ix_notifications_pupil_tax_code"),
        "notifications",
        ["pupil_tax_code"],
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index(op.f("ix_notifications_pupil_tax_code"), table_name="notifications")

    for column in ("booker_tax_code", "pupil_tax_code"):
        op.drop_constraint(
            op.f(f"fk_notifications_{column}_people"),
            "notifications",
            type_="foreignkey",
        )
        op.drop_column("notifications", column)

    op.execute("DELETE FROM notifications WHERE kind = 'BOOKING_ADDED'")
    op.execute("DELETE FROM muted_notification_kinds WHERE kind = 'BOOKING_ADDED'")
