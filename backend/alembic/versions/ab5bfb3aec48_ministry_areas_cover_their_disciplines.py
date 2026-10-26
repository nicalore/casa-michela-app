"""A ministry subject's areas include those of its disciplines

Revision ID: ab5bfb3aec48
Revises: 8e065af1b2de
Create Date: 2026-10-25
"""

from alembic import op

revision = "ab5bfb3aec48"
down_revision = "8e065af1b2de"
branch_labels = None
depends_on = None

# A discipline moved to another area left its ministry subjects without it. Areas no
# discipline uses any more stay: one chosen on purpose cannot be told apart.
_ADD_MISSING = """
    UPDATE ministry_subjects
    SET area = ministry_subjects.area || missing.areas
    FROM (
        SELECT ministry_association_subjects.ministry_subject_id,
               array_agg(DISTINCT association_subjects.area) AS areas
        FROM ministry_association_subjects
        JOIN association_subjects
          ON association_subjects.id
           = ministry_association_subjects.association_subject_id
        JOIN ministry_subjects AS owner
          ON owner.id = ministry_association_subjects.ministry_subject_id
        WHERE NOT (association_subjects.area = ANY (owner.area))
        GROUP BY ministry_association_subjects.ministry_subject_id
    ) AS missing
    WHERE missing.ministry_subject_id = ministry_subjects.id
"""


def upgrade() -> None:
    op.execute(_ADD_MISSING)


def downgrade() -> None:
    # One-way: which areas were added is not recorded.
    pass
