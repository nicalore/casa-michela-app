"""add mode to presences

No unique index over (student, date, mode, start_time), which is what the
availabilities carry: presences were written for a long while with nothing
stopping two identical ones, and there are days in the wild holding a pair.
Creating the index would have to throw one of each pair away — along with the
bookings hanging off it — which is not a thing a migration should do quietly.
The service refuses overlapping stretches outright, which is the stronger rule
of the two; the index can be added once the duplicates have been looked at by
someone who knows which of the two is the real one.

Revision ID: c1a93b7e5d24
Revises: b8e52d3caf16
Create Date: 2026-08-03 17:40:00.000000

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "c1a93b7e5d24"
down_revision = "b8e52d3caf16"
branch_labels = None
depends_on = None

_DEFAULT_MODE = "presence"


def upgrade() -> None:
    # Everything written before this column existed was time spent in the
    # building: being reachable online had no way of being said, so nothing
    # stored is it.
    op.add_column(
        "presences",
        sa.Column("mode", sa.String(length=20), nullable=False, server_default=_DEFAULT_MODE),
    )
    op.alter_column("presences", "mode", server_default=None)

    op.create_check_constraint(
        op.f("ck_presences_presence_mode_valid"),
        "presences",
        "mode IN ('presence', 'online')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_presences_presence_mode_valid"),
        "presences",
        type_="check",
    )

    op.drop_column("presences", "mode")
