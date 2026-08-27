"""add sector to study_programs

Revision ID: d3f7a2b81c45
Revises: c4d81a55e903
Create Date: 2026-07-31
"""

import sqlalchemy as sa

from alembic import op

revision = "d3f7a2b81c45"
down_revision = "c4d81a55e903"
branch_labels = None
depends_on = None

_SEPARATOR = "|"


def upgrade() -> None:
    op.add_column("study_programs", sa.Column("sector", sa.String(length=100), nullable=True))

    # Sector first, shortened name second: the second UPDATE destroys the
    # source the first one reads from.
    op.execute(
        f"""
        UPDATE study_programs
        SET sector = btrim(split_part(name, '{_SEPARATOR}', 1))
        WHERE position('{_SEPARATOR}' in name) > 0
          AND btrim(split_part(name, '{_SEPARATOR}', 1)) <> ''
        """
    )

    op.create_check_constraint(
        "study_program_sector_not_blank",
        "study_programs",
        "sector IS NULL OR length(trim(sector)) > 0",
    )
    op.create_check_constraint(
        "sector_no_surrounding_whitespace",
        "study_programs",
        "sector IS NULL OR sector = btrim(sector)",
    )

    # Swap the constraints BEFORE shortening names: without the sector inside
    # name, (level, name) is no longer a key.
    op.drop_constraint("uq_level_program_name", "study_programs", type_="unique")
    op.execute(
        "CREATE UNIQUE INDEX uq_level_sector_program_name "
        "ON study_programs (level, coalesce(sector, ''), name)"
    )

    # Only where stripping still leaves a name: a row like "Liceo classico |"
    # would end up empty and fail the not-blank check.
    op.execute(
        f"""
        UPDATE study_programs
        SET name = btrim(split_part(name, '{_SEPARATOR}', 2))
        WHERE sector IS NOT NULL
          AND btrim(split_part(name, '{_SEPARATOR}', 2)) <> ''
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_level_sector_program_name")

    # Fold the sector back into the name so the old (level, name) key holds again.
    op.execute(
        f"""
        UPDATE study_programs
        SET name = sector || ' {_SEPARATOR} ' || name
        WHERE sector IS NOT NULL
        """
    )

    op.create_unique_constraint(
        "uq_level_program_name",
        "study_programs",
        ["level", "name"],
    )

    op.drop_constraint(
        "sector_no_surrounding_whitespace",
        "study_programs",
        type_="check",
    )
    op.drop_constraint("study_program_sector_not_blank", "study_programs", type_="check")
    op.drop_column("study_programs", "sector")