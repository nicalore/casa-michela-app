"""The birth city may stay unsaid for a birthplace abroad

Revision ID: b7e2d4c91f03
Revises: 9a04d35f4c86
Create Date: 2026-09-20
"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "b7e2d4c91f03"
down_revision = "9a04d35f4c86"
branch_labels = None
depends_on = None

_PEOPLE: Final[str] = "people"

_COLUMN: Final[str] = "birth_city"

# Names and expressions exactly as the models render them, or autogenerate redoes them.
_NOT_BLANK: Final[str] = f"ck_{_PEOPLE}_{_COLUMN}_not_blank"

_REQUIRED_IN_ITALY: Final[str] = f"ck_{_PEOPLE}_{_COLUMN}_required_in_italy"


def upgrade() -> None:
    op.alter_column(
        _PEOPLE,
        _COLUMN,
        existing_type=sa.String(length=100),
        nullable=True,
    )

    op.drop_constraint(op.f(_NOT_BLANK), _PEOPLE, type_="check")
    op.create_check_constraint(
        op.f(_NOT_BLANK),
        _PEOPLE,
        f"{_COLUMN} IS NULL OR length(trim({_COLUMN})) > 0",
    )

    op.create_check_constraint(
        op.f(_REQUIRED_IN_ITALY),
        _PEOPLE,
        f"{_COLUMN} IS NOT NULL OR birth_province = 'EE'",
    )


def downgrade() -> None:
    op.drop_constraint(op.f(_REQUIRED_IN_ITALY), _PEOPLE, type_="check")

    op.drop_constraint(op.f(_NOT_BLANK), _PEOPLE, type_="check")
    op.create_check_constraint(
        op.f(_NOT_BLANK),
        _PEOPLE,
        f"length(trim({_COLUMN})) > 0",
    )

    # Fails if anyone born abroad left the city unsaid: NOT NULL must not invent one.
    op.alter_column(
        _PEOPLE,
        _COLUMN,
        existing_type=sa.String(length=100),
        nullable=False,
    )
