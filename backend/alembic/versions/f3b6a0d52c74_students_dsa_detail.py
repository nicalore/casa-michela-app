"""students: free-text DSA detail, required for DSA certifications

Revision ID: f3b6a0d52c74
Revises: e2a9d47c3b18
Create Date: 2026-08-26

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "f3b6a0d52c74"
down_revision = "e2a9d47c3b18"
branch_labels = None
depends_on = None

_STUDENTS: Final[str] = "students"

_COLUMN: Final[str] = "certification_dsa_detail"

# Name and expression exactly as app/models/constraints.py renders them, so a
# later autogenerate does not propose recreating them.
_CHECKS: Final[tuple[tuple[str, str], ...]] = (
    (
        f"{_COLUMN}_requires_dsa_type",
        # IS NOT DISTINCT FROM is NULL-safe: with a plain "=", an absent
        # certification type would yield NULL and the check would pass anyway.
        f"{_COLUMN} IS NULL OR certification_type IS NOT DISTINCT FROM 'DSA'",
    ),
    (
        f"{_COLUMN}_not_blank",
        f"{_COLUMN} IS NULL OR length(trim({_COLUMN})) > 0",
    ),
    (
        f"{_COLUMN}_no_surrounding_whitespace",
        f"{_COLUMN} IS NULL OR {_COLUMN} = btrim({_COLUMN})",
    ),
)

_SAYS_WHICH: Final[str] = "dsa_certification_says_which"

_SAYS_WHICH_CONDITION: Final[str] = (
    f"certification_type IS DISTINCT FROM 'DSA' OR {_COLUMN} IS NOT NULL"
)


def upgrade() -> None:
    op.add_column(
        _STUDENTS,
        sa.Column(_COLUMN, sa.String(length=255), nullable=True),
    )

    for name, condition in _CHECKS:
        op.create_check_constraint(
            op.f(f"ck_{_STUDENTS}_{name}"),
            _STUDENTS,
            condition,
        )

    # NOT VALID: constrains new writes only, not existing rows. Alembic cannot
    # express it, hence the raw ALTER TABLE.
    op.execute(
        f"""
        ALTER TABLE {_STUDENTS}
        ADD CONSTRAINT ck_{_STUDENTS}_{_SAYS_WHICH}
        CHECK ({_SAYS_WHICH_CONDITION}) NOT VALID
        """
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f(f"ck_{_STUDENTS}_{_SAYS_WHICH}"),
        _STUDENTS,
        type_="check",
    )

    for name, _ in _CHECKS:
        op.drop_constraint(
            op.f(f"ck_{_STUDENTS}_{name}"),
            _STUDENTS,
            type_="check",
        )

    op.drop_column(_STUDENTS, _COLUMN)
