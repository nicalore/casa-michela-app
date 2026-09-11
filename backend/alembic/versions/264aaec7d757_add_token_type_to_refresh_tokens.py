"""add token type to refresh tokens

Revision ID: 264aaec7d757
Revises: 5851f4355938
Create Date: 2026-06-30 23:42:30.184307

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '264aaec7d757'
down_revision: str | Sequence[str] | None = '5851f4355938'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    token_type_enum = sa.Enum('REFRESH', 'PASSWORD_RESET', name='token_type_enum')
    token_type_enum.create(op.get_bind())

    op.add_column('refresh_tokens', sa.Column(
        'token_type',
        sa.Enum('REFRESH', 'PASSWORD_RESET', name='token_type_enum'),
        server_default='REFRESH',
        nullable=False,
    ))


def downgrade() -> None:
    op.drop_column('refresh_tokens', 'token_type')
    sa.Enum(name='token_type_enum').drop(op.get_bind())
