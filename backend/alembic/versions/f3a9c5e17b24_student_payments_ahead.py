"""hours paid ahead under an hourly tariff

Revision ID: f3a9c5e17b24
Revises: e4c7a9d2b816
Create Date: 2026-11-12
"""

import sqlalchemy as sa

from alembic import op

revision = "f3a9c5e17b24"
down_revision = "e4c7a9d2b816"
branch_labels = None
depends_on = None

_TABLE = "student_payments"

_CHECKS = (
    (
        "student_payment_ahead_minutes_only_for_ahead",
        "(kind = 'AHEAD') = (ahead_minutes IS NOT NULL)",
    ),
    (
        "student_payment_ahead_minutes_positive",
        "ahead_minutes IS NULL OR ahead_minutes > 0",
    ),
    (
        "student_payment_ahead_has_rate",
        "kind <> 'AHEAD' OR cents_per_hour IS NOT NULL",
    ),
)


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE student_payment_kind_enum ADD VALUE IF NOT EXISTS 'AHEAD'"
        )

    op.add_column(_TABLE, sa.Column("ahead_minutes", sa.Integer(), nullable=True))

    for name, condition in _CHECKS:
        op.create_check_constraint(op.f(f"ck_{_TABLE}_{name}"), _TABLE, condition)


# Postgres cannot drop an enum value: the payments of the new kind go instead.
def downgrade() -> None:
    for name, _ in _CHECKS:
        op.drop_constraint(op.f(f"ck_{_TABLE}_{name}"), _TABLE, type_="check")

    op.execute("DELETE FROM student_payments WHERE kind = 'AHEAD'")
    op.drop_column(_TABLE, "ahead_minutes")
