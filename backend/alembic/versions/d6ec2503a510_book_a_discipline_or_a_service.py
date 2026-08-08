"""book a discipline or a service

Until now an hour could only be asked for as a ministry subject with some of
its disciplines. Two more ways to ask were missing: a discipline on its own,
for what is not on the pupil's own syllabus, and a service, which is not a
subject at all.

Rather than a discriminator column, the kind is read off the two new columns:
both null means the old kind, and the CHECK stops them being set together.
That a request of the new kinds carries no ministry subjects — a child table,
which no CHECK can count — is held in the ORM (see Booking).

The two columns are nullable and nothing is backfilled: every row that exists
is a ministry-subject request, which is exactly what two nulls mean.

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
        # Il nome di un servizio è una chiave naturale mutabile.
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
