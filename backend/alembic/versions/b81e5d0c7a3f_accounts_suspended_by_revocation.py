"""Accounts suspended by a membership's revocation

Revision ID: b81e5d0c7a3f
Revises: a6d2f9c41e07
Create Date: 2026-10-01
"""

from alembic import op

revision = "b81e5d0c7a3f"
down_revision = "a6d2f9c41e07"
branch_labels = None
depends_on = None

_REVOKED_MEMBERS = """
    SELECT latest.member_tax_code
    FROM memberships latest
    WHERE latest.revocation <> 'NO'
      AND latest.year = (
          SELECT max(other.year)
          FROM memberships other
          WHERE other.member_tax_code = latest.member_tax_code
      )
"""


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE account_status_enum ADD VALUE IF NOT EXISTS 'REVOKED'")

    op.execute(
        f"UPDATE accounts SET status = 'REVOKED' WHERE tax_code IN ({_REVOKED_MEMBERS})"
    )
    op.execute(
        "UPDATE refresh_tokens SET revoked_at = now() "
        "WHERE token_type = 'REFRESH' AND revoked_at IS NULL "
        "AND account_tax_code IN "
        "(SELECT tax_code FROM accounts WHERE status = 'REVOKED')"
    )


# Postgres cannot drop an enum value: those accounts fall back to a manual suspension.
def downgrade() -> None:
    op.execute("UPDATE accounts SET status = 'DISABLED' WHERE status = 'REVOKED'")
