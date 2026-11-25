"""Closed drafts hold SQL NULL, not the JSON null that read as a draft open

Revision ID: 68839402691c
Revises: 2241e709f603
Create Date: 2026-11-24
"""

from alembic import op

revision = "68839402691c"
down_revision = "2241e709f603"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "UPDATE calendar_publications SET draft_snapshot = NULL "
        "WHERE jsonb_typeof(draft_snapshot) = 'null'"
    )


def downgrade() -> None:
    # Nothing to undo: SQL NULL is what a closed draft always meant.
    pass
