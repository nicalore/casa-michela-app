"""lesson kinds become a list and gain a new STUDY kind

Revision ID: 4bfe4c59c661
Revises: d6ec2503a510
Create Date: 2026-08-04 16:30:52.883385

"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "4bfe4c59c661"
down_revision = "d6ec2503a510"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("COMMIT")
    op.execute("ALTER TYPE booking_tag_enum ADD VALUE IF NOT EXISTS 'STUDY'")

    op.add_column(
        "bookings",
        sa.Column(
            "tags",
            postgresql.ARRAY(
                postgresql.ENUM(name="booking_tag_enum", create_type=False)
            ),
            nullable=False,
            server_default="{}",
        ),
    )

    # Backfill: the single kind becomes a one-element list, nothing is lost.
    op.execute("UPDATE bookings SET tags = ARRAY[tag] WHERE tag IS NOT NULL")

    op.drop_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        type_="check",
    )
    op.drop_column("bookings", "tag")
    op.create_check_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        "service_name IS NULL OR (cardinality(tags) = 0 AND topic IS NULL)",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        type_="check",
    )

    op.add_column(
        "bookings",
        sa.Column(
            "tag",
            postgresql.ENUM(name="booking_tag_enum", create_type=False),
            nullable=True,
        ),
    )

    # Only the first tag survives the downgrade; the rest are lost for good.
    op.execute("UPDATE bookings SET tag = tags[1] WHERE cardinality(tags) > 0")

    op.drop_column("bookings", "tags")
    op.create_check_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        "service_name IS NULL OR (tag IS NULL AND topic IS NULL)",
    )

    # The added enum value stays: Postgres cannot drop a value from a type, and
    # recreating the type would mean rewriting every column that uses it.
