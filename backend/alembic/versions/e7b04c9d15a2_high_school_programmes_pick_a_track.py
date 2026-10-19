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

# Plain groups: SQLAlchemy reads ":percorso" in "(?:percorso" as a bind parameter.
_HAND_WRITTEN_SUFFIX: Final[str] = (
    r"\s*\((percorso\s+)?(biennio|triennio|quadriennale)\)\s*$"
)

_STRIPPED_NAME: Final[str] = (
    f"btrim(regexp_replace(name, '{_HAND_WRITTEN_SUFFIX}', '', 'i'))"
)


def upgrade() -> None:
    bind = op.get_bind()

    # add_column emits no CREATE TYPE: the type is created first, create_type=False.
    postgresql.ENUM(*_TRACKS, name=_ENUM).create(bind, checkfirst=True)

    op.add_column(
        _TABLE,
        sa.Column(
            _COLUMN,
            postgresql.ENUM(name=_ENUM, create_type=False),
            nullable=True,
        ),
    )

    # Backfilled before the constraints; a CASE yields text, hence the enum cast.
    # A 1-5 span fits no track: QUADRIENNALE strands the fewest years (only year 5).
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

    # Out before the names are stripped: without the suffix two cycles collide here.
    op.execute(f"DROP INDEX IF EXISTS {_OLD_INDEX}")

    # Strips the hand-written cycle suffix, unless nothing else would remain.
    op.execute(
        f"""
        UPDATE {_TABLE}
        SET name = {_STRIPPED_NAME}
        WHERE {_COLUMN} IS NOT NULL
          AND {_STRIPPED_NAME} <> ''
        """
    )

    # Rebuilt once the names are final: the years now keep the two cycles apart.
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

    # Fails if two programmes differ only by their span, which the old key ignores.
    op.execute(f"DROP INDEX IF EXISTS {_NEW_INDEX}")
    op.execute(
        f"CREATE UNIQUE INDEX {_OLD_INDEX} "
        f"ON {_TABLE} (level, coalesce(sector, ''), name)"
    )

    # Years and stripped names stay as the backfill left them: not recoverable.
    op.drop_column(_TABLE, _COLUMN)

    # Last: the column using the type has to be gone first.
    postgresql.ENUM(name=_ENUM).drop(bind, checkfirst=True)
