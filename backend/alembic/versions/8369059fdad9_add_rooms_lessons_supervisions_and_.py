"""aggiunge stanze, lezioni, responsabili e pubblicazioni del calendario

Il calendario di una giornata: le lezioni, la stanza in cui ogni docente
convocato lavora, chi risponde di quella stanza e quali fasce sono state
pubblicate.

Le chiavi esterne che reggono una lezione sono in RESTRICT e non in CASCADE,
al contrario di tutto il resto dello schema: il calendario è un archivio, e
nulla di ciò che lo sostiene può essere cancellato mentre la lezione esiste.

Revision ID: 8369059fdad9
Revises: 4bfe4c59c661
Create Date: 2026-08-09 18:16:56.934922

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "8369059fdad9"
down_revision = "4bfe4c59c661"
branch_labels = None
depends_on = None

# What a lesson's band is, as the database computes it. The same bounds as
# app/core/time_band.py, written the way a generated column wants them.
_BAND_EXPRESSION = (
    "CASE WHEN start_time < TIME '13:00' THEN 'MORNING' "
    "WHEN start_time < TIME '19:00' THEN 'AFTERNOON' "
    "ELSE 'EVENING' END"
)


def upgrade() -> None:
    # First of all, and the reason is the composite foreign key below: Postgres
    # wants a UNIQUE on exactly the columns a foreign key references. It is
    # trivially satisfied, id being the primary key already, and costs one
    # redundant index for the guarantee that a lesson's date and mode can never
    # drift from its availability's.
    op.create_unique_constraint(
        "uq_availability_identity",
        "availabilities",
        ["id", "date", "mode"],
    )

    op.create_table(
        "rooms",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=1000), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("id > 0", name=op.f("ck_rooms_positive_room_id")),
        sa.CheckConstraint(
            "capacity IS NULL OR capacity > 0",
            name=op.f("ck_rooms_room_capacity_positive"),
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name=op.f("ck_rooms_name_not_blank"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name=op.f("ck_rooms_description_not_blank"),
        ),
        sa.CheckConstraint(
            "name IS NULL OR name = btrim(name)",
            name=op.f("ck_rooms_name_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR description = btrim(description)",
            name=op.f("ck_rooms_description_no_surrounding_whitespace"),
        ),
        sa.UniqueConstraint("name", name="uq_room_name"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_rooms")),
    )

    op.create_table(
        "lessons",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("availability_id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("teacher_mode", sa.String(length=20), nullable=False),
        sa.Column("mode", sa.String(length=20), nullable=False),
        sa.Column(
            "band",
            sa.String(length=20),
            sa.Computed(_BAND_EXPRESSION, persisted=True),
            nullable=False,
        ),
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
        sa.CheckConstraint("id > 0", name=op.f("ck_lessons_positive_lesson_id")),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_lessons_lesson_end_after_start"),
        ),
        sa.CheckConstraint(
            "end_time - start_time >= INTERVAL '30 minutes'",
            name=op.f("ck_lessons_lesson_minimum_duration"),
        ),
        sa.CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name=op.f("ck_lessons_lesson_time_step"),
        ),
        sa.CheckConstraint(
            "mode IN ('presence', 'online')",
            name=op.f("ck_lessons_lesson_mode_valid"),
        ),
        sa.CheckConstraint(
            "teacher_mode IN ('presence', 'online')",
            name=op.f("ck_lessons_lesson_teacher_mode_valid"),
        ),
        sa.CheckConstraint(
            "teacher_mode = 'presence' OR mode = 'online'",
            name=op.f("ck_lessons_lesson_mode_compatible"),
        ),
        sa.CheckConstraint(
            "start_time >= TIME '06:00' AND start_time < TIME '23:00' "
            "AND end_time <= TIME '23:00'",
            name=op.f("ck_lessons_lesson_within_day"),
        ),
        sa.CheckConstraint(
            "(start_time < TIME '13:00' AND end_time <= TIME '13:00') "
            "OR (start_time >= TIME '13:00' AND start_time < TIME '19:00' "
            "AND end_time <= TIME '19:00') "
            "OR start_time >= TIME '19:00'",
            name=op.f("ck_lessons_lesson_within_band"),
        ),
        sa.ForeignKeyConstraint(
            ["availability_id", "date", "teacher_mode"],
            ["availabilities.id", "availabilities.date", "availabilities.mode"],
            name="lessons_availability_fkey",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_lessons")),
    )
    op.create_index(
        op.f("ix_lessons_availability_id"),
        "lessons",
        ["availability_id"],
        unique=False,
    )
    op.create_index(
        "ux_lesson_slot",
        "lessons",
        ["availability_id", "start_time"],
        unique=True,
    )
    op.create_index("ix_lesson_day", "lessons", ["date", "band"], unique=False)

    op.create_table(
        "lesson_bookings",
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("booking_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["lesson_id"],
            ["lessons.id"],
            name=op.f("fk_lesson_bookings_lesson_id_lessons"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            name=op.f("fk_lesson_bookings_booking_id_bookings"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint(
            "lesson_id",
            "booking_id",
            name=op.f("pk_lesson_bookings"),
        ),
    )
    op.create_index(
        op.f("ix_lesson_bookings_booking_id"),
        "lesson_bookings",
        ["booking_id"],
        unique=False,
    )

    op.create_table(
        "lesson_disciplines",
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("association_subject_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["lesson_id"],
            ["lessons.id"],
            name=op.f("fk_lesson_disciplines_lesson_id_lessons"),
            ondelete="CASCADE",
        ),
        # Named by hand: the convention would run to 65 characters, Postgres
        # truncates at 63, and the downgrade would then not find it.
        sa.ForeignKeyConstraint(
            ["association_subject_id"],
            ["association_subjects.id"],
            name="lesson_disciplines_subject_fkey",
            ondelete="RESTRICT",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "lesson_id",
            "association_subject_id",
            name=op.f("pk_lesson_disciplines"),
        ),
    )
    op.create_index(
        op.f("ix_lesson_disciplines_association_subject_id"),
        "lesson_disciplines",
        ["association_subject_id"],
        unique=False,
    )

    op.create_table(
        "teacher_room_assignments",
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
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
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_teacher_room_assignments_teacher_tax_code_teachers"),
            ondelete="RESTRICT",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["room_id"],
            ["rooms.id"],
            name=op.f("fk_teacher_room_assignments_room_id_rooms"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "teacher_tax_code",
            name=op.f("pk_teacher_room_assignments"),
        ),
        # The target of the supervisions' composite foreign key.
        sa.UniqueConstraint(
            "date",
            "teacher_tax_code",
            "room_id",
            name="uq_teacher_room_identity",
        ),
    )
    op.create_index(
        op.f("ix_teacher_room_assignments_room_id"),
        "teacher_room_assignments",
        ["room_id"],
        unique=False,
    )

    op.create_table(
        "room_supervisions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
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
            "id > 0",
            name=op.f("ck_room_supervisions_positive_room_supervision_id"),
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_room_supervisions_room_supervision_end_after_start"),
        ),
        sa.CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name=op.f("ck_room_supervisions_room_supervision_time_step"),
        ),
        # The only foreign key, and it does the work of three: a supervisor is a
        # teacher who has that room on that day, and nothing else can be one.
        sa.ForeignKeyConstraint(
            ["date", "teacher_tax_code", "room_id"],
            [
                "teacher_room_assignments.date",
                "teacher_room_assignments.teacher_tax_code",
                "teacher_room_assignments.room_id",
            ],
            name="room_supervisions_assignment_fkey",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_room_supervisions")),
    )
    op.create_index(
        op.f("ix_room_supervisions_room_id"),
        "room_supervisions",
        ["room_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_room_supervisions_teacher_tax_code"),
        "room_supervisions",
        ["teacher_tax_code"],
        unique=False,
    )
    op.create_index(
        "ux_room_supervision_slot",
        "room_supervisions",
        ["date", "room_id", "teacher_tax_code", "start_time"],
        unique=True,
    )

    op.create_table(
        "calendar_publications",
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(length=20), nullable=False),
        sa.Column(
            "published_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("published_by", sa.String(length=16), nullable=True),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f("ck_calendar_publications_calendar_publication_band_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["published_by"],
            ["administrators.tax_code"],
            name=op.f("fk_calendar_publications_published_by_administrators"),
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "band",
            name=op.f("pk_calendar_publications"),
        ),
    )
    op.create_index(
        op.f("ix_calendar_publications_published_by"),
        "calendar_publications",
        ["published_by"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_calendar_publications_published_by"),
        table_name="calendar_publications",
    )
    op.drop_table("calendar_publications")

    op.drop_index("ux_room_supervision_slot", table_name="room_supervisions")
    op.drop_index(
        op.f("ix_room_supervisions_teacher_tax_code"),
        table_name="room_supervisions",
    )
    op.drop_index(
        op.f("ix_room_supervisions_room_id"),
        table_name="room_supervisions",
    )
    op.drop_table("room_supervisions")

    op.drop_index(
        op.f("ix_teacher_room_assignments_room_id"),
        table_name="teacher_room_assignments",
    )
    op.drop_table("teacher_room_assignments")

    op.drop_index(
        op.f("ix_lesson_disciplines_association_subject_id"),
        table_name="lesson_disciplines",
    )
    op.drop_table("lesson_disciplines")

    op.drop_index(
        op.f("ix_lesson_bookings_booking_id"),
        table_name="lesson_bookings",
    )
    op.drop_table("lesson_bookings")

    op.drop_index("ix_lesson_day", table_name="lessons")
    op.drop_index("ux_lesson_slot", table_name="lessons")
    op.drop_index(op.f("ix_lessons_availability_id"), table_name="lessons")
    op.drop_table("lessons")

    op.drop_table("rooms")

    op.drop_constraint(
        "uq_availability_identity",
        "availabilities",
        type_="unique",
    )
