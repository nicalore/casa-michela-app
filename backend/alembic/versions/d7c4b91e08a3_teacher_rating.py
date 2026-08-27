"""add teacher rating (numeric 0-5 in half-point steps, default 3.5)

Revision ID: d7c4b91e08a3
Revises: f3b6a0d52c74
Create Date: 2026-08-26

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "d7c4b91e08a3"
down_revision = "f3b6a0d52c74"
branch_labels = None
depends_on = None

_TEACHERS: Final[str] = "teachers"

_COLUMN: Final[str] = "rating"

_DEFAULT: Final[str] = "3.5"

# Name and expression exactly as app/models/teacher.py renders them, so a
# later autogenerate does not propose recreating them.
_CHECKS: Final[tuple[tuple[str, str], ...]] = (
    (f"{_COLUMN}_within_bounds", f"{_COLUMN} BETWEEN 0 AND 5"),
    (f"{_COLUMN}_in_half_points", f"{_COLUMN} % 0.5 = 0"),
)


def upgrade() -> None:
    op.add_column(
        _TEACHERS,
        sa.Column(
            _COLUMN,
            sa.Numeric(precision=2, scale=1),
            nullable=False,
            server_default=sa.text(_DEFAULT),
        ),
    )

    for name, condition in _CHECKS:
        op.create_check_constraint(
            op.f(f"ck_{_TEACHERS}_{name}"),
            _TEACHERS,
            condition,
        )


def downgrade() -> None:
    for name, _ in _CHECKS:
        op.drop_constraint(
            op.f(f"ck_{_TEACHERS}_{name}"),
            _TEACHERS,
            type_="check",
        )

    op.drop_column(_TEACHERS, _COLUMN)
