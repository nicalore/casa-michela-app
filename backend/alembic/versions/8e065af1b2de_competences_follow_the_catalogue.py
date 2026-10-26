"""A teacher's programmes follow the catalogue's links to the discipline

Revision ID: 8e065af1b2de
Revises: e1a7c5d3b924
Create Date: 2026-10-25
"""

from alembic import op

revision = "8e065af1b2de"
down_revision = "e1a7c5d3b924"
branch_labels = None
depends_on = None

_TODAY = "(now() AT TIME ZONE 'Europe/Rome')::date"

# Catalogue edits used to leave open the pairs they unlinked.
_STRAY = """
    teaching_competences.valid_to IS NULL
    AND NOT EXISTS (
        SELECT 1
        FROM ministry_association_subjects
        JOIN study_program_subjects
          ON study_program_subjects.ministry_subject_id
           = ministry_association_subjects.ministry_subject_id
        WHERE ministry_association_subjects.association_subject_id
            = teaching_competences.association_subject_id
          AND study_program_subjects.study_program_id
            = teaching_competences.study_program_id
    )
"""


def upgrade() -> None:
    # As replace_competences: a row opened today leaves no history.
    op.execute(
        f"DELETE FROM teaching_competences WHERE valid_from >= {_TODAY} AND {_STRAY}"
    )
    op.execute(f"UPDATE teaching_competences SET valid_to = {_TODAY} WHERE {_STRAY}")


def downgrade() -> None:
    # One-way: the closed rows stay closed.
    pass
