"""The notification telling a teacher their payment receipt is available

Revision ID: 2241e709f603
Revises: 544c259864a9
Create Date: 2026-11-22
"""

from alembic import op

revision = "2241e709f603"
down_revision = "544c259864a9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'PAYMENT_RECEIPT_AVAILABLE'"
        )


def downgrade() -> None:
    # The enum value stays: Postgres cannot drop one.
    op.execute(
        "DELETE FROM notifications WHERE kind::text = 'PAYMENT_RECEIPT_AVAILABLE'"
    )
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind::text = 'PAYMENT_RECEIPT_AVAILABLE'"
    )
