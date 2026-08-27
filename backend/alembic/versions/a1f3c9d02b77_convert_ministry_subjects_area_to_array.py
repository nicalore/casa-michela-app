"""Convert ministry_subjects.area to array of 1-3 unique values

Revision ID: a1f3c9d02b77
Revises: 264aaec7d757
Create Date: 2026-07-03 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'a1f3c9d02b77'
down_revision: Union[str, Sequence[str], None] = '264aaec7d757'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    subject_area_enum = postgresql.ENUM(
        'HUMANITIES', 'LINGUISTICS', 'SCIENCES',
        name='subject_area_enum',
        create_type=False,
    )

    # Each existing row has a single value: wrapped into a one-element array.
    op.alter_column(
        'ministry_subjects',
        'area',
        type_=postgresql.ARRAY(subject_area_enum),
        postgresql_using='ARRAY[area]',
        nullable=False,
    )

    op.create_check_constraint(
        'ministry_subject_area_count_range',
        'ministry_subjects',
        'cardinality(area) BETWEEN 1 AND 3',
    )
    op.create_check_constraint(
        'ministry_subject_area_no_duplicates',
        'ministry_subjects',
        """
        (area[1] IS DISTINCT FROM area[2] OR area[2] IS NULL)
        AND (area[1] IS DISTINCT FROM area[3] OR area[3] IS NULL)
        AND (area[2] IS DISTINCT FROM area[3] OR area[3] IS NULL)
        """,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('ministry_subject_area_no_duplicates', 'ministry_subjects', type_='check')
    op.drop_constraint('ministry_subject_area_count_range', 'ministry_subjects', type_='check')

    subject_area_enum = postgresql.ENUM(
        'HUMANITIES', 'LINGUISTICS', 'SCIENCES',
        name='subject_area_enum',
        create_type=False,
    )

    # Downgrade keeps only the first area; any others are lost irreversibly.
    op.alter_column(
        'ministry_subjects',
        'area',
        type_=subject_area_enum,
        postgresql_using='area[1]',
        nullable=False,
    )