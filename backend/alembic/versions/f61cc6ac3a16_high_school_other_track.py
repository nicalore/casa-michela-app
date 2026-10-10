"""high school track OTHER with typed years replaces QUADRIENNALE

Revision ID: f61cc6ac3a16
Revises: d7e3b1a5c902
Create Date: 2026-10-09
"""

from typing import Final

from alembic import op

revision = "f61cc6ac3a16"
down_revision = "d7e3b1a5c902"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "study_programs"

_COLUMN: Final[str] = "high_school_track"

_ENUM: Final[str] = "high_school_track_enum"

_RETIRED_ENUM: Final[str] = "high_school_track_enum_retired"

_TRACK_YEARS_MATCH: Final[str] = "study_program_track_years_match"

_FIXED_TRACKS: Final[str] = (
    f"{_COLUMN} IS NULL "
    f"OR ({_COLUMN} = 'BIENNIO' AND min_year = 1 AND max_year = 2) "
    f"OR ({_COLUMN} = 'TRIENNIO' AND min_year = 3 AND max_year = 5) "
)


def _swap_enum(values: tuple[str, ...], old_value: str, new_value: str) -> None:
    # Postgres cannot drop an enum value, and a value added in this
    # transaction cannot be used before it commits: the type is rebuilt.
    op.execute(f"ALTER TYPE {_ENUM} RENAME TO {_RETIRED_ENUM}")

    labels = ", ".join(f"'{value}'" for value in values)
    op.execute(f"CREATE TYPE {_ENUM} AS ENUM ({labels})")

    op.execute(
        f"""
        ALTER TABLE {_TABLE}
        ALTER COLUMN {_COLUMN} TYPE {_ENUM}
        USING (CASE {_COLUMN}::text
            WHEN '{old_value}' THEN '{new_value}'
            ELSE {_COLUMN}::text
        END)::{_ENUM}
        """
    )

    op.execute(f"DROP TYPE {_RETIRED_ENUM}")


def upgrade() -> None:
    # Out first: its 'QUADRIENNALE' would not cast to the new type.
    op.drop_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        type_="check",
    )

    # QUADRIENNALE rows keep their 1-4 span, now typed rather than implied.
    _swap_enum(("BIENNIO", "TRIENNIO", "OTHER"), "QUADRIENNALE", "OTHER")

    op.create_check_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        f"{_FIXED_TRACKS}"
        f"OR ({_COLUMN} = 'OTHER' "
        f"AND (min_year, max_year) NOT IN ((1, 2), (3, 5)))",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        type_="check",
    )

    _swap_enum(("BIENNIO", "TRIENNIO", "QUADRIENNALE"), "OTHER", "QUADRIENNALE")

    # Fails if an OTHER programme spans anything but 1-4: QUADRIENNALE cannot
    # hold it, and no other track can either.
    op.create_check_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        f"{_FIXED_TRACKS}"
        f"OR ({_COLUMN} = 'QUADRIENNALE' AND min_year = 1 AND max_year = 4)",
    )
