"""a booking lasts from fifteen minutes to five hours

Revision ID: e9446a9f7478
Revises: 1a168c70438b
Create Date: 2026-11-02
"""

from alembic import op

revision = "e9446a9f7478"
down_revision = "1a168c70438b"
branch_labels = None
depends_on = None


def _replace_duration_check(maximum: int) -> None:
    name = op.f("ck_bookings_booking_duration_step")
    op.drop_constraint(name, "bookings", type_="check")
    op.create_check_constraint(
        name,
        "bookings",
        f"duration BETWEEN 15 AND {maximum} AND duration % 15 = 0",
    )


def upgrade() -> None:
    _replace_duration_check(300)


# Refused while a booking runs past two hours.
def downgrade() -> None:
    _replace_duration_check(120)
