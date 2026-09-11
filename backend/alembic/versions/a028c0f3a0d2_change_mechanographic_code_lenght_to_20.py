"""change mechanographic code lenght to 20

Revision ID: a028c0f3a0d2
Revises: 5abee1e46f43
Create Date: 2026-06-15 00:19:57.216758

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'a028c0f3a0d2'
down_revision: str | Sequence[str] | None = '5abee1e46f43'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.alter_column('schools', 'mechanographic_code',
               existing_type=sa.VARCHAR(length=10),
               type_=sa.String(length=20),
               existing_nullable=False)
    op.alter_column('teaching_offerings', 'school_mechanographic_code',
               existing_type=sa.VARCHAR(length=10),
               type_=sa.String(length=20),
               existing_nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column('teaching_offerings', 'school_mechanographic_code',
               existing_type=sa.String(length=20),
               type_=sa.VARCHAR(length=10),
               existing_nullable=False)
    op.alter_column('schools', 'mechanographic_code',
               existing_type=sa.String(length=20),
               type_=sa.VARCHAR(length=10),
               existing_nullable=False)
