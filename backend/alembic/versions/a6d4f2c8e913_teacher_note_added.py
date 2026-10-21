"""The administrators told of a teacher's new note

Revision ID: a6d4f2c8e913
Revises: f2b8d6a4c179
Create Date: 2026-10-20
"""

import sqlalchemy as sa

from alembic import op

revision = "a6d4f2c8e913"
down_revision = "f2b8d6a4c179"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'TEACHER_NOTE_ADDED'"
        )

    # Two full names in one title: the longest still fit.
    op.alter_column(
        "notifications",
        "title",
        type_=sa.String(length=500),
        existing_type=sa.String(length=120),
        existing_nullable=False,
    )

    op.add_column(
        "notifications",
        sa.Column("teacher_note_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        op.f("fk_notifications_teacher_note_id_teacher_notes"),
        "notifications",
        "teacher_notes",
        ["teacher_note_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_notifications_teacher_note_id"),
        "notifications",
        ["teacher_note_id"],
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index(
        op.f("ix_notifications_teacher_note_id"),
        table_name="notifications",
    )
    op.drop_constraint(
        op.f("fk_notifications_teacher_note_id_teacher_notes"),
        "notifications",
        type_="foreignkey",
    )
    op.drop_column("notifications", "teacher_note_id")
    op.execute("DELETE FROM notifications WHERE kind = 'TEACHER_NOTE_ADDED'")
    op.execute(
        "DELETE FROM muted_notification_kinds WHERE kind = 'TEACHER_NOTE_ADDED'"
    )
    op.alter_column(
        "notifications",
        "title",
        type_=sa.String(length=120),
        existing_type=sa.String(length=500),
        existing_nullable=False,
    )
