"""add updated_at to students and teachers

Revision ID: 69e755fafde0
Revises: 67807fb512da
Create Date: 2026-07-05 16:49:49.656518

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '69e755fafde0'
down_revision: Union[str, Sequence[str], None] = '67807fb512da'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "students",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.add_column(
        "teachers",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

def downgrade() -> None:
    op.drop_column("teachers", "updated_at")
    op.drop_column("students", "updated_at")