"""add the missing text checks on teachers' education fields

Revision ID: b1e7c94af205
Revises: c5a92e1b74d3
Create Date: 2026-08-26

"""

from typing import Final

from alembic import op

revision = "b1e7c94af205"
down_revision = "c5a92e1b74d3"
branch_labels = None
depends_on = None

_TEACHERS: Final[str] = "teachers"

_COLUMNS: Final[tuple[str, ...]] = ("school_education", "university_education")

# Name and expression exactly as app/models/constraints.py renders them, so a
# later autogenerate does not propose recreating them.
_CHECKS: Final[tuple[tuple[str, str], ...]] = tuple(
    check
    for column in _COLUMNS
    for check in (
        (
            f"{column}_not_blank",
            f"{column} IS NULL OR length(trim({column})) > 0",
        ),
        (
            f"{column}_no_surrounding_whitespace",
            f"{column} IS NULL OR {column} = btrim({column})",
        ),
    )
)


def upgrade() -> None:
    for column in _COLUMNS:
        # IS DISTINCT FROM is NULL-safe: it skips rows already clean and NULL
        # rows, which a plain "=" would pointlessly rewrite every run.
        op.execute(
            f"""
            UPDATE {_TEACHERS}
            SET {column} = nullif(btrim({column}), '')
            WHERE {column} IS DISTINCT FROM nullif(btrim({column}), '')
            """
        )

    for constraint_name, condition in _CHECKS:
        op.create_check_constraint(
            op.f(f"ck_{_TEACHERS}_{constraint_name}"),
            _TEACHERS,
            condition,
        )


def downgrade() -> None:
    for constraint_name, _condition in _CHECKS:
        op.drop_constraint(
            op.f(f"ck_{_TEACHERS}_{constraint_name}"),
            _TEACHERS,
            type_="check",
        )
