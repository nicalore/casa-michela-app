"""published calendars reopen as drafts, tracked by a content fingerprint

Revision ID: a4f7c2e91b30
Revises: 80eaead2769d
Create Date: 2026-08-20 00:00:00.000000

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "a4f7c2e91b30"
down_revision = "80eaead2769d"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "calendar_publications"
_COLUMN: Final[str] = "draft_fingerprint"

_LENGTH: Final[int] = 64


def upgrade() -> None:
    op.add_column(
        _TABLE,
        sa.Column(_COLUMN, sa.String(length=_LENGTH), nullable=True),
    )


def downgrade() -> None:
    op.drop_column(_TABLE, _COLUMN)
