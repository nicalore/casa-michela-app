"""teachers are judged on ten criteria, half a point each, instead of a free rating

Revision ID: 581e1a6d1733
Revises: ab5bfb3aec48
Create Date: 2026-10-25

"""

from typing import Final

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "581e1a6d1733"
down_revision = "ab5bfb3aec48"
branch_labels = None
depends_on = None

_TEACHERS: Final[str] = "teachers"

_CRITERIA: Final[str] = "met_criteria"

# Frozen copy of TEACHER_CRITERIA: a later list change gets its own migration.
_KEYS: Final[tuple[str, ...]] = (
    "competence",
    "clarity",
    "empathy",
    "motivation",
    "relationship",
    "transparency",
    "flexibility",
    "proactivity",
    "reliability",
    "rules",
)

_KNOWN: Final[str] = (
    f"{_CRITERIA} <@ ARRAY[" + ", ".join(f"'{key}'" for key in _KEYS) + "]::varchar[]"
)

_RATING: Final[str] = "rating"

_RATING_DEFAULT: Final[str] = "2.5"

_RATING_CHECKS: Final[tuple[tuple[str, str], ...]] = (
    (f"{_RATING}_within_bounds", f"{_RATING} BETWEEN 0 AND 5"),
    (f"{_RATING}_in_half_points", f"{_RATING} % 0.5 = 0"),
)


# Every teacher starts again from none met: a free rating says nothing of the criteria.
def upgrade() -> None:
    op.add_column(
        _TEACHERS,
        sa.Column(
            _CRITERIA,
            postgresql.ARRAY(sa.String(length=20)),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
    )
    op.create_check_constraint(
        op.f(f"ck_{_TEACHERS}_{_CRITERIA}_known"),
        _TEACHERS,
        _KNOWN,
    )

    for name, _ in _RATING_CHECKS:
        op.drop_constraint(op.f(f"ck_{_TEACHERS}_{name}"), _TEACHERS, type_="check")

    op.drop_column(_TEACHERS, _RATING)


def downgrade() -> None:
    op.add_column(
        _TEACHERS,
        sa.Column(
            _RATING,
            sa.Numeric(precision=2, scale=1),
            nullable=False,
            server_default=sa.text(_RATING_DEFAULT),
        ),
    )

    for name, condition in _RATING_CHECKS:
        op.create_check_constraint(op.f(f"ck_{_TEACHERS}_{name}"), _TEACHERS, condition)

    op.drop_constraint(
        op.f(f"ck_{_TEACHERS}_{_CRITERIA}_known"),
        _TEACHERS,
        type_="check",
    )
    op.drop_column(_TEACHERS, _CRITERIA)
