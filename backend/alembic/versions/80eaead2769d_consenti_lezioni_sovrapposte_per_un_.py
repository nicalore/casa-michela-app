"""allow overlapping lessons for a teacher: drop the unique (availability_id, start_time) index

Revision ID: 80eaead2769d
Revises: 8369059fdad9
Create Date: 2026-08-10 00:00:00.000000

"""

from typing import Final

from alembic import op

# revision identifiers, used by Alembic.
revision = "80eaead2769d"
down_revision = "8369059fdad9"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "lessons"
_INDEX: Final[str] = "ux_lesson_slot"
_COLUMNS: Final[list[str]] = ["availability_id", "start_time"]


def upgrade() -> None:
    # Literal name: op.f() would look for an index that never existed under it.
    op.drop_index(_INDEX, table_name=_TABLE)


def downgrade() -> None:
    # May fail on a database that meanwhile holds overlapping lessons: the price
    # of reinstating a loosened constraint.
    op.create_index(_INDEX, _TABLE, _COLUMNS, unique=True)
