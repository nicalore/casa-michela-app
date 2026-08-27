"""add a flag for teachers still attending high school

Revision ID: c5a92e1b74d3
Revises: 77997e6cdae9
Create Date: 2026-08-26

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "c5a92e1b74d3"
down_revision = "77997e6cdae9"
branch_labels = None
depends_on = None

_TEACHERS: Final[str] = "teachers"

_COLUMN: Final[str] = "is_high_school_student"

_CONSTRAINT: Final[str] = "ck_teachers_high_school_student_has_no_university_education"


def upgrade() -> None:
    op.add_column(
        _TEACHERS,
        sa.Column(
            _COLUMN,
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )

    op.create_check_constraint(
        op.f(_CONSTRAINT),
        _TEACHERS,
        f"NOT {_COLUMN} OR university_education IS NULL",
    )


def downgrade() -> None:
    op.drop_constraint(op.f(_CONSTRAINT), _TEACHERS, type_="check")
    op.drop_column(_TEACHERS, _COLUMN)
