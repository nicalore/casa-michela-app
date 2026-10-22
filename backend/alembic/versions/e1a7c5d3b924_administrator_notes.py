"""Administrators' notes on teachers, and the teacher told of each new one

Revision ID: e1a7c5d3b924
Revises: d8f2b6a4c1e7
Create Date: 2026-10-22
"""

import sqlalchemy as sa

from alembic import op

revision = "e1a7c5d3b924"
down_revision = "d8f2b6a4c1e7"
branch_labels = None
depends_on = None

_ONE_NOTE_BEFORE = "num_nonnulls(technical_note_id, methodological_note_id) = 1"
_ONE_NOTE_AFTER = (
    "num_nonnulls(technical_note_id, methodological_note_id, "
    "administrator_note_id) = 1"
)


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'ADMINISTRATOR_NOTE_ADDED'"
        )

    op.create_table(
        "administrator_notes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("teacher_tax_code", sa.String(16), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=False),
        sa.Column("text", sa.String(10000), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(text)) > 0",
            name=op.f("ck_administrator_notes_text_not_blank"),
        ),
        sa.CheckConstraint(
            "text IS NULL OR text = btrim(text)",
            name=op.f("ck_administrator_notes_text_no_surrounding_whitespace"),
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_administrator_notes_teacher_tax_code_teachers"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_administrator_notes_author_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_administrator_notes")),
    )
    op.create_index(
        op.f("ix_administrator_notes_teacher_tax_code"),
        "administrator_notes",
        ["teacher_tax_code"],
    )
    op.create_index(
        op.f("ix_administrator_notes_author_tax_code"),
        "administrator_notes",
        ["author_tax_code"],
    )

    op.add_column(
        "student_note_images",
        sa.Column("administrator_note_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        op.f("fk_student_note_images_administrator_note_id_administrator_notes"),
        "student_note_images",
        "administrator_notes",
        ["administrator_note_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_student_note_images_administrator_note_id"),
        "student_note_images",
        ["administrator_note_id"],
    )
    op.create_unique_constraint(
        op.f("uq_student_note_images_administrator_note_id"),
        "student_note_images",
        ["administrator_note_id", "image_key"],
    )
    op.drop_constraint(
        op.f("ck_student_note_images_one_note"),
        "student_note_images",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_student_note_images_one_note"),
        "student_note_images",
        _ONE_NOTE_AFTER,
    )

    op.add_column(
        "notifications",
        sa.Column("administrator_note_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        op.f("fk_notifications_administrator_note_id_administrator_notes"),
        "notifications",
        "administrator_notes",
        ["administrator_note_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_notifications_administrator_note_id"),
        "notifications",
        ["administrator_note_id"],
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index(
        op.f("ix_notifications_administrator_note_id"),
        table_name="notifications",
    )
    op.drop_constraint(
        op.f("fk_notifications_administrator_note_id_administrator_notes"),
        "notifications",
        type_="foreignkey",
    )
    op.drop_column("notifications", "administrator_note_id")
    op.execute("DELETE FROM notifications WHERE kind = 'ADMINISTRATOR_NOTE_ADDED'")
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind = 'ADMINISTRATOR_NOTE_ADDED'"
    )

    op.execute(
        "DELETE FROM student_note_images WHERE administrator_note_id IS NOT NULL"
    )
    op.drop_constraint(
        op.f("ck_student_note_images_one_note"),
        "student_note_images",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_student_note_images_one_note"),
        "student_note_images",
        _ONE_NOTE_BEFORE,
    )
    op.drop_constraint(
        op.f("uq_student_note_images_administrator_note_id"),
        "student_note_images",
        type_="unique",
    )
    op.drop_index(
        op.f("ix_student_note_images_administrator_note_id"),
        table_name="student_note_images",
    )
    op.drop_constraint(
        op.f("fk_student_note_images_administrator_note_id_administrator_notes"),
        "student_note_images",
        type_="foreignkey",
    )
    op.drop_column("student_note_images", "administrator_note_id")

    op.drop_index(
        op.f("ix_administrator_notes_author_tax_code"),
        table_name="administrator_notes",
    )
    op.drop_index(
        op.f("ix_administrator_notes_teacher_tax_code"),
        table_name="administrator_notes",
    )
    op.drop_table("administrator_notes")
