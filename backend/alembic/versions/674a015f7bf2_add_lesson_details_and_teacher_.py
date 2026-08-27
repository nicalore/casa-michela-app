"""add booking details, teacher preferences and presence minimum duration

Revision ID: 674a015f7bf2
Revises: c1a93b7e5d24
Create Date: 2026-08-04 12:20:30.770774

"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "674a015f7bf2"
down_revision = "c1a93b7e5d24"
branch_labels = None
depends_on = None

_BOOKING_TAG_ENUM = "booking_tag_enum"
_TEACHER_PREFERENCE_TYPE_ENUM = "teacher_preference_type_enum"

_BOOKING_TAGS = (
    "ORAL_TEST",
    "WRITTEN_TEST",
    "HOMEWORK",
    "ENRICHMENT",
    "OUTLINES",
    "EXAM_PREPARATION",
    "CERTIFICATION",
)

_TEACHER_PREFERENCE_TYPES = ("PREFERRED", "NOT_PREFERRED")

# Named exactly as the helpers in app/models/constraints.py render them, so a
# later autogenerate does not propose dropping and recreating them.
_TEXT_CHECKS = (
    ("topic", "topic_not_blank", "topic IS NULL OR length(trim(topic)) > 0"),
    (
        "topic",
        "topic_no_surrounding_whitespace",
        "topic IS NULL OR topic = btrim(topic)",
    ),
    ("notes", "notes_not_blank", "notes IS NULL OR length(trim(notes)) > 0"),
    (
        "notes",
        "notes_no_surrounding_whitespace",
        "notes IS NULL OR notes = btrim(notes)",
    ),
)


def upgrade() -> None:
    bind = op.get_bind()

    # Created up front, and referenced with create_type=False below, so that
    # the column and the table do not each try to create them again.
    booking_tag_enum = postgresql.ENUM(*_BOOKING_TAGS, name=_BOOKING_TAG_ENUM)
    booking_tag_enum.create(bind, checkfirst=True)

    teacher_preference_type_enum = postgresql.ENUM(
        *_TEACHER_PREFERENCE_TYPES,
        name=_TEACHER_PREFERENCE_TYPE_ENUM,
    )
    teacher_preference_type_enum.create(bind, checkfirst=True)

    op.add_column(
        "bookings",
        sa.Column(
            "tag",
            postgresql.ENUM(name=_BOOKING_TAG_ENUM, create_type=False),
            nullable=True,
        ),
    )
    op.add_column("bookings", sa.Column("topic", sa.String(length=255), nullable=True))
    op.add_column("bookings", sa.Column("notes", sa.String(length=1000), nullable=True))

    for _column, constraint_name, condition in _TEXT_CHECKS:
        op.create_check_constraint(
            op.f(f"ck_bookings_{constraint_name}"),
            "bookings",
            condition,
        )

    op.create_table(
        "booking_teacher_preferences",
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column(
            "preference_type",
            postgresql.ENUM(name=_TEACHER_PREFERENCE_TYPE_ENUM, create_type=False),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            name=op.f("fk_booking_teacher_preferences_booking_id_bookings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_booking_teacher_preferences_teacher_tax_code_teachers"),
            # tax_code is a mutable natural key.
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "booking_id",
            "teacher_tax_code",
            name=op.f("pk_booking_teacher_preferences"),
        ),
    )
    op.create_index(
        op.f("ix_booking_teacher_preferences_teacher_tax_code"),
        "booking_teacher_preferences",
        ["teacher_tax_code"],
        unique=False,
    )

    op.create_check_constraint(
        op.f("ck_presences_presence_minimum_duration"),
        "presences",
        "end_time - start_time >= INTERVAL '30 minutes'",
    )


def downgrade() -> None:
    bind = op.get_bind()

    op.drop_constraint(
        op.f("ck_presences_presence_minimum_duration"),
        "presences",
        type_="check",
    )

    op.drop_index(
        op.f("ix_booking_teacher_preferences_teacher_tax_code"),
        table_name="booking_teacher_preferences",
    )
    op.drop_table("booking_teacher_preferences")

    for _column, constraint_name, _condition in _TEXT_CHECKS:
        op.drop_constraint(
            op.f(f"ck_bookings_{constraint_name}"),
            "bookings",
            type_="check",
        )

    op.drop_column("bookings", "notes")
    op.drop_column("bookings", "topic")
    op.drop_column("bookings", "tag")

    # Last: the columns using them have to be gone first.
    postgresql.ENUM(name=_TEACHER_PREFERENCE_TYPE_ENUM).drop(bind, checkfirst=True)
    postgresql.ENUM(name=_BOOKING_TAG_ENUM).drop(bind, checkfirst=True)
