"""An adult pupil needs no leave to go home early

Revision ID: d4e8b1c73a56
Revises: c7f3a9e21b64
Create Date: 2026-09-09
"""

from alembic import op

revision = "d4e8b1c73a56"
down_revision = "c7f3a9e21b64"
branch_labels = None
depends_on = None

# The register set the flag on every adult pupil, where the question does not arise.
_CLEAR_ADULTS = """
    UPDATE students
    SET early_exit_start_date = NULL,
        early_exit_end_date = NULL,
        authorized_early_exit = false
    FROM people
    WHERE people.tax_code = students.tax_code
      AND students.authorized_early_exit
      AND people.birth_date <= CURRENT_DATE - INTERVAL '18 years'
"""

_DROP_ADULT_LINES = """
    DELETE FROM early_exit_schedules
    USING people
    WHERE people.tax_code = early_exit_schedules.student_tax_code
      AND people.birth_date <= CURRENT_DATE - INTERVAL '18 years'
"""


def upgrade() -> None:
    op.execute(_DROP_ADULT_LINES)
    op.execute(_CLEAR_ADULTS)


def downgrade() -> None:
    # One-way: which adults carried the flag by mistake is not recorded.
    pass
