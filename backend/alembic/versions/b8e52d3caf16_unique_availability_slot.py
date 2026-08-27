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
    # Race-proof backstop for the service's overlap rule: only identical starts
    # (double-click shape); true overlap would need exclusion + btree_gist.
    op.create_index(
        _INDEX_NAME,
        "availabilities",
        ["teacher_tax_code", "date", "mode", "start_time"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(_INDEX_NAME, table_name="availabilities")
