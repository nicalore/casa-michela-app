"""convert ministry subjects area to array

Revision ID: 1f48d805faae
Revises: a1f3c9d02b77
Create Date: 2026-07-03 00:16:40.062735

"""
from collections.abc import Sequence

# revision identifiers, used by Alembic.
revision: str = '1f48d805faae'
down_revision: str | Sequence[str] | None = 'a1f3c9d02b77'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
