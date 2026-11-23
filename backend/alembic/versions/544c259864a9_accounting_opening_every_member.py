"""accounting opening lists every member of the 15th

The first snapshot took only who was collaborating at the deploy: whoever comes
back while the set-up is open was never listed. Every teacher and pupil who was a
member on 15 November gets a row now; the lists still show only who collaborates.
Once the set-up is closed, rows never confirmed go: nobody waits for them.

Revision ID: 544c259864a9
Revises: 38856c796e61
Create Date: 2026-11-23
"""

from alembic import op

revision = "544c259864a9"
down_revision = "38856c796e61"
branch_labels = None
depends_on = None

_OPEN = "EXISTS (SELECT 1 FROM accounting_openings WHERE closed_at IS NULL)"
_CLOSED = "EXISTS (SELECT 1 FROM accounting_openings WHERE closed_at IS NOT NULL)"

# Enrolled on the 15th, on a membership never revoked.
_MEMBER_ON_THE_15TH = """
    EXISTS (
      SELECT 1 FROM memberships ms
      WHERE ms.member_tax_code = r.tax_code
        AND ms.revocation = 'NO'
        AND ms.start_date <= DATE '2026-11-15'
        AND ms.end_date + ms.renewal_period_days > DATE '2026-11-15'
    )
"""


def upgrade() -> None:
    for table, role in (
        ("teacher_openings", "teachers"),
        ("pupil_openings", "students"),
    ):
        op.execute(
            f"INSERT INTO {table} (tax_code) SELECT r.tax_code FROM {role} r "
            f"WHERE {_OPEN} AND {_MEMBER_ON_THE_15TH} "
            f"AND NOT EXISTS (SELECT 1 FROM {table} o WHERE o.tax_code = r.tax_code)",
        )
        op.execute(f"DELETE FROM {table} WHERE confirmed_at IS NULL AND {_CLOSED}")


def downgrade() -> None:
    # One-way: the rows added cannot be told apart from the first snapshot.
    pass
