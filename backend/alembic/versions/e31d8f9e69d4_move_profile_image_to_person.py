"""Move profile image to Person

Revision ID: e31d8f9e69d4
Revises: 67a3ebc57620
Create Date: 2026-06-21 11:44:18.069020

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e31d8f9e69d4'
down_revision: Union[str, Sequence[str], None] = '67a3ebc57620'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "people",
        sa.Column(
            "profile_image_url",
            sa.String(length=2048),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("people", "profile_image_url")
    # ### end Alembic commands ###
