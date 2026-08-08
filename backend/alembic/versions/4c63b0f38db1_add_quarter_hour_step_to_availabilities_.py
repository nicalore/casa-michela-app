"""add quarter hour step to availabilities and presences

Revision ID: 4c63b0f38db1
Revises: f1c11e517ef6
Create Date: 2026-07-25 20:58:57.437226

"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "4c63b0f38db1"
down_revision = "f1c11e517ef6"
branch_labels = None
depends_on = None

_TIME_STEP_CONDITION = (
    "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
    "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0"
)


def upgrade() -> None:
    op.create_check_constraint(
        op.f("ck_availabilities_availability_time_step"),
        "availabilities",
        _TIME_STEP_CONDITION,
    )
    op.create_check_constraint(
        op.f("ck_presences_presence_time_step"),
        "presences",
        _TIME_STEP_CONDITION,
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_presences_presence_time_step"),
        "presences",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_availabilities_availability_time_step"),
        "availabilities",
        type_="check",
    )
