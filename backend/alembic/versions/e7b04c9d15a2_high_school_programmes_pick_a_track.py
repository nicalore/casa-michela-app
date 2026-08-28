"""high school programmes pick a track instead of a year range

Revision ID: e7b04c9d15a2
Revises: b8f2c05d3a91
Create Date: 2026-08-28
"""

from typing import Final

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "e7b04c9d15a2"
down_revision = "b8f2c05d3a91"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "study_programs"

_COLUMN: Final[str] = "high_school_track"

_ENUM: Final[str] = "high_school_track_enum"

_TRACKS: Final[tuple[str, ...]] = ("BIENNIO", "TRIENNIO", "QUADRIENNALE")

_OLD_INDEX: Final[str] = "uq_level_sector_program_name"

_NEW_INDEX: Final[str] = "uq_level_sector_program_name_years"

_ONLY_FOR_HIGH_SCHOOL: Final[str] = "study_program_track_only_for_high_school"

_TRACK_YEARS_MATCH: Final[str] = "study_program_track_years_match"

# Plain groups on purpose: in "(?:percorso" SQLAlchemy would read ":percorso"
# as a bind parameter and refuse to run the statement.
_HAND_WRITTEN_SUFFIX: Final[str] = (
    r"\s*\((percorso\s+)?(biennio|triennio|quadriennale)\)\s*$"
)

_STRIPPED_NAME: Final[str] = (
    f"btrim(regexp_replace(name, '{_HAND_WRITTEN_SUFFIX}', '', 'i'))"
)


def upgrade() -> None:
    bind = op.get_bind()

    # Alembic does not emit CREATE TYPE on its own: the type has to exist
    # before the column, which then references it with create_type=False.
    postgresql.ENUM(*_TRACKS, name=_ENUM).create(bind, checkfirst=True)

    op.add_column(
        _TABLE,
        sa.Column(
            _COLUMN,
            postgresql.ENUM(name=_ENUM, create_type=False),
            nullable=True,
        ),
    )

    # Backfill before the constraints: ADD CONSTRAINT validates the rows that
    # are already there. A CASE resolves to text, which Postgres refuses to
    # assign to an enum column, hence the cast.
    #
    # No existing span maps faithfully: the standard high school covers 1-5,
    # which is none of the three. QUADRIENNALE is the fallback because it is
    # the arm that strands the fewest enrolments — only year 5, where TRIENNIO
    # would strand years 1 and 2.
    op.execute(
        f"""
        UPDATE {_TABLE}
        SET {_COLUMN} = (CASE
            WHEN max_year <= 2 THEN 'BIENNIO'
            WHEN min_year >= 3 THEN 'TRIENNIO'
            ELSE 'QUADRIENNALE'
        END)::{_ENUM}
        WHERE level = 'HIGH_SCHOOL'
        """
    )

    # A second statement, because it reads the column the first one writes.
    op.execute(
        f"""
        UPDATE {_TABLE}
        SET min_year = CASE {_COLUMN}
                WHEN 'TRIENNIO' THEN 3
                ELSE 1
            END,
            max_year = CASE {_COLUMN}
                WHEN 'BIENNIO' THEN 2
                WHEN 'TRIENNIO' THEN 5
                ELSE 4
            END
        WHERE {_COLUMN} IS NOT NULL
        """
    )

    # Out before the names are stripped: dropping the suffix is exactly what
    # makes a biennio and a triennio of one course collide on this key.
    op.execute(f"DROP INDEX IF EXISTS {_OLD_INDEX}")

    # The cycle used to be written into the name by hand. Now that it is a
    # column, strip that suffix — but only where a name survives it, so a row
    # called just "(triennio)" is left alone.
    op.execute(
        f"""
        UPDATE {_TABLE}
        SET name = {_STRIPPED_NAME}
        WHERE {_COLUMN} IS NOT NULL
          AND {_STRIPPED_NAME} <> ''
        """
    )

    # Rebuilt only once the names are final. The years are what keep the two
    # rows apart now that the suffix is gone.
    op.execute(
        f"CREATE UNIQUE INDEX {_NEW_INDEX} "
        f"ON {_TABLE} (level, coalesce(sector, ''), name, min_year, max_year)"
    )

    op.create_check_constraint(
        op.f(f"ck_{_TABLE}_{_ONLY_FOR_HIGH_SCHOOL}"),
        _TABLE,
        f"(level = 'HIGH_SCHOOL') = ({_COLUMN} IS NOT NULL)",
    )
    op.create_check_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        f"{_COLUMN} IS NULL "
        f"OR ({_COLUMN} = 'BIENNIO' AND min_year = 1 AND max_year = 2) "
        f"OR ({_COLUMN} = 'TRIENNIO' AND min_year = 3 AND max_year = 5) "
        f"OR ({_COLUMN} = 'QUADRIENNALE' AND min_year = 1 AND max_year = 4)",
    )


def downgrade() -> None:
    bind = op.get_bind()

    op.drop_constraint(
        op.f(f"ck_{_TABLE}_{_TRACK_YEARS_MATCH}"),
        _TABLE,
        type_="check",
    )
    op.drop_constraint(
        op.f(f"ck_{_TABLE}_{_ONLY_FOR_HIGH_SCHOOL}"),
        _TABLE,
        type_="check",
    )

    # Fails if two programmes were created that differ only by their span:
    # without the years the old key cannot tell them apart any more.
    op.execute(f"DROP INDEX IF EXISTS {_NEW_INDEX}")
    op.execute(
        f"CREATE UNIQUE INDEX {_OLD_INDEX} "
        f"ON {_TABLE} (level, coalesce(sector, ''), name)"
    )

    # min_year, max_year and the stripped names keep whatever the backfill
    # left them: neither the span nor the hand-written suffix is recoverable.
    op.drop_column(_TABLE, _COLUMN)

    # Last: the column using the type has to be gone first.
    postgresql.ENUM(name=_ENUM).drop(bind, checkfirst=True)
