"""one availability slot per teacher, day, mode and start time

Revision ID: b8e52d3caf16
Revises: a7d41c2b9e05
Create Date: 2026-08-02 12:05:00.000000

"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "b8e52d3caf16"
down_revision = "a7d41c2b9e05"
branch_labels = None
depends_on = None

_INDEX_NAME = "ux_availability_slot"


def upgrade() -> None:
    # The service refuses any stretch that runs over another one of the same
    # teacher, day and mode; this is the same rule at the one point two racing
    # requests cannot both win. It only catches the exact same start, which is
    # the shape a double click produces — the overlapping-but-not-identical case
    # stays the service's, since saying it in SQL takes an exclusion constraint
    # and the btree_gist extension with it.
    op.create_index(
        _INDEX_NAME,
        "availabilities",
        ["teacher_tax_code", "date", "mode", "start_time"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(_INDEX_NAME, table_name="availabilities")
