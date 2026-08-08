"""add availabilities, presences, bookings, subjects_requested

Revision ID: f1c11e517ef6
Revises: 6051b979a419
Create Date: 2026-07-25 16:22:53.818924

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "f1c11e517ef6"
down_revision = "6051b979a419"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "presences",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.Column("student_tax_code", sa.String(length=16), nullable=False),
        sa.Column("booker_tax_code", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_presences_presence_end_after_start"),
        ),
        sa.CheckConstraint("id > 0", name=op.f("ck_presences_positive_presence_id")),
        sa.ForeignKeyConstraint(
            ["booker_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_presences_booker_tax_code_people"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_presences_student_tax_code_students"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_presences")),
    )
    op.create_index(
        op.f("ix_presences_booker_tax_code"),
        "presences",
        ["booker_tax_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_presences_student_tax_code"),
        "presences",
        ["student_tax_code"],
        unique=False,
    )

    op.create_table(
        "availabilities",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_availabilities_availability_end_after_start"),
        ),
        sa.CheckConstraint(
            "id > 0",
            name=op.f("ck_availabilities_positive_availability_id"),
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_availabilities_teacher_tax_code_teachers"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_availabilities")),
    )
    op.create_index(
        op.f("ix_availabilities_teacher_tax_code"),
        "availabilities",
        ["teacher_tax_code"],
        unique=False,
    )

    op.create_table(
        "bookings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("presence_id", sa.Integer(), nullable=False),
        sa.Column("duration", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "duration BETWEEN 30 AND 120 AND duration % 15 = 0",
            name=op.f("ck_bookings_booking_duration_step"),
        ),
        sa.CheckConstraint("id > 0", name=op.f("ck_bookings_positive_booking_id")),
        sa.ForeignKeyConstraint(
            ["presence_id"],
            ["presences.id"],
            name=op.f("fk_bookings_presence_id_presences"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_bookings")),
    )
    op.create_index(
        op.f("ix_bookings_presence_id"),
        "bookings",
        ["presence_id"],
        unique=False,
    )

    op.create_table(
        "subjects_requested",
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("ministry_subject_id", sa.Integer(), nullable=False),
        sa.Column("association_subject_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            name=op.f("fk_subjects_requested_booking_id_bookings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["ministry_subject_id", "association_subject_id"],
            [
                "ministry_association_subjects.ministry_subject_id",
                "ministry_association_subjects.association_subject_id",
            ],
            name="subjects_requested_mas_fkey",
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "booking_id",
            "ministry_subject_id",
            "association_subject_id",
            name=op.f("pk_subjects_requested"),
        ),
    )


def downgrade() -> None:
    op.drop_table("subjects_requested")

    op.drop_index(op.f("ix_bookings_presence_id"), table_name="bookings")
    op.drop_table("bookings")

    op.drop_index(
        op.f("ix_availabilities_teacher_tax_code"), table_name="availabilities"
    )
    op.drop_table("availabilities")

    op.drop_index(op.f("ix_presences_student_tax_code"), table_name="presences")
    op.drop_index(op.f("ix_presences_booker_tax_code"), table_name="presences")
    op.drop_table("presences")
