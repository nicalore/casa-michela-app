"""drafts store a snapshot of the day instead of just its fingerprint

Revision ID: b8d3e5f21a47
Revises: a4f7c2e91b30
Create Date: 2026-08-23 00:00:00.000000

"""

from typing import Final

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "b8d3e5f21a47"
down_revision = "a4f7c2e91b30"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "calendar_publications"
_OLD: Final[str] = "draft_fingerprint"
_NEW: Final[str] = "draft_snapshot"


def upgrade() -> None:
    op.add_column(
        _TABLE,
        sa.Column(_NEW, postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    # Drafts open at migration time have no snapshot to restart from, so they
    # are closed; their content stays written and can be reopened.
    op.drop_column(_TABLE, _OLD)


def downgrade() -> None:
    op.add_column(_TABLE, sa.Column(_OLD, sa.String(length=64), nullable=True))
    op.drop_column(_TABLE, _NEW)
