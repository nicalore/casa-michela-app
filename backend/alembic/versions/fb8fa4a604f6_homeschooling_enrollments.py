"""a school year may be homeschooling, which has no school

Revision ID: fb8fa4a604f6
Revises: f61cc6ac3a16
Create Date: 2026-10-09
"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "fb8fa4a604f6"
down_revision = "f61cc6ac3a16"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "school_enrollments"

_PROGRAM_FK: Final[str] = "fk_school_enrollments_study_program_id_study_programs"

_SCHOOL_OR_HOMESCHOOLING: Final[str] = "ck_school_enrollments_school_or_homeschooling"


def upgrade() -> None:
    op.add_column(
        _TABLE,
        sa.Column(
            "homeschooling",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )

    op.alter_column(_TABLE, "school_id", existing_type=sa.Integer(), nullable=True)

    # The pair FK skips a row without a school, so the programme needs its own.
    op.create_foreign_key(
        op.f(_PROGRAM_FK),
        _TABLE,
        "study_programs",
        ["study_program_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    op.create_check_constraint(
        op.f(_SCHOOL_OR_HOMESCHOOLING),
        _TABLE,
        "homeschooling = (school_id IS NULL)",
    )


def downgrade() -> None:
    op.drop_constraint(op.f(_SCHOOL_OR_HOMESCHOOLING), _TABLE, type_="check")
    op.drop_constraint(op.f(_PROGRAM_FK), _TABLE, type_="foreignkey")

    # Fails while a homeschooling year exists: there is no school to put back.
    op.alter_column(_TABLE, "school_id", existing_type=sa.Integer(), nullable=False)

    op.drop_column(_TABLE, "homeschooling")
