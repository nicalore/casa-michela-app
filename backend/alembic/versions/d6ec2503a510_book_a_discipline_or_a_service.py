"""book a discipline or a service

Revision ID: d6ec2503a510
Revises: deff88ef5884
Create Date: 2026-08-04 13:55:03.290664

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "d6ec2503a510"
down_revision = "deff88ef5884"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "bookings",
        sa.Column("association_subject_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "bookings",
        sa.Column("service_name", sa.String(length=255), nullable=True),
    )

    op.create_index(
        op.f("ix_bookings_association_subject_id"),
        "bookings",
        ["association_subject_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_bookings_service_name"),
        "bookings",
        ["service_name"],
        unique=False,
    )

    op.create_foreign_key(
        op.f("fk_bookings_association_subject_id_association_subjects"),
        "bookings",
        "association_subjects",
        ["association_subject_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        op.f("fk_bookings_service_name_services"),
        "bookings",
        "services",
        ["service_name"],
        ["name"],
        # A service name is a mutable natural key.
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    op.create_check_constraint(
        op.f("ck_bookings_booking_single_request_kind"),
        "bookings",
        "num_nonnulls(association_subject_id, service_name) <= 1",
    )
    op.create_check_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        "service_name IS NULL OR (tag IS NULL AND topic IS NULL)",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_bookings_booking_single_request_kind"),
        "bookings",
        type_="check",
    )

    op.drop_constraint(
        op.f("fk_bookings_service_name_services"),
        "bookings",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_bookings_association_subject_id_association_subjects"),
        "bookings",
        type_="foreignkey",
    )

    op.drop_index(op.f("ix_bookings_service_name"), table_name="bookings")
    op.drop_index(
        op.f("ix_bookings_association_subject_id"),
        table_name="bookings",
    )

    op.drop_column("bookings", "service_name")
    op.drop_column("bookings", "association_subject_id")
