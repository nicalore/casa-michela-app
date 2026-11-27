"""online hours at the weekend paid ahead, under any tariff

Revision ID: c7e2f9a4d318
Revises: 68839402691c
Create Date: 2026-11-27
"""

from alembic import op

revision = "c7e2f9a4d318"
down_revision = "68839402691c"
branch_labels = None
depends_on = None

_TABLE = "student_payments"

# Name, condition before, condition after.
_CHECKS = (
    (
        "student_payment_package_or_month_has_tariff",
        "kind = 'HOURS' OR tariff_id IS NOT NULL",
        "kind IN ('HOURS', 'WEEKEND_AHEAD') OR tariff_id IS NOT NULL",
    ),
    (
        "student_payment_ahead_minutes_only_for_ahead",
        "(kind = 'AHEAD') = (ahead_minutes IS NOT NULL)",
        "(kind IN ('AHEAD', 'WEEKEND_AHEAD')) = (ahead_minutes IS NOT NULL)",
    ),
    (
        "student_payment_ahead_has_rate",
        "kind <> 'AHEAD' OR cents_per_hour IS NOT NULL",
        "kind NOT IN ('AHEAD', 'WEEKEND_AHEAD') OR cents_per_hour IS NOT NULL",
    ),
)


def _replace(after: bool) -> None:
    for name, before, later in _CHECKS:
        full = op.f(f"ck_{_TABLE}_{name}")
        op.drop_constraint(full, _TABLE, type_="check")
        op.create_check_constraint(full, _TABLE, later if after else before)


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE student_payment_kind_enum "
            "ADD VALUE IF NOT EXISTS 'WEEKEND_AHEAD'"
        )

    _replace(after=True)


# Postgres cannot drop an enum value: the payments of the new kind go instead.
def downgrade() -> None:
    op.execute("DELETE FROM student_payments WHERE kind = 'WEEKEND_AHEAD'")
    _replace(after=False)
