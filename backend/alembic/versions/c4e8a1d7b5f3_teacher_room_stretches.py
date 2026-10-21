"""A teacher may change room during the day

Revision ID: c4e8a1d7b5f3
Revises: b7e3c1f9a2d4
Create Date: 2026-10-21
"""

import sqlalchemy as sa

from alembic import op

revision = "c4e8a1d7b5f3"
down_revision = "b7e3c1f9a2d4"
branch_labels = None
depends_on = None

_MIDNIGHT = sa.text("'00:00:00'")


def upgrade() -> None:
    op.drop_constraint(
        "room_supervisions_assignment_fkey",
        "room_supervisions",
        type_="foreignkey",
    )
    op.drop_constraint(
        "uq_teacher_room_identity",
        "teacher_room_assignments",
        type_="unique",
    )

    # Every existing row becomes a stretch from midnight: the same day in one room.
    op.add_column(
        "teacher_room_assignments",
        sa.Column("start_time", sa.Time(), nullable=False, server_default=_MIDNIGHT),
    )
    op.alter_column("teacher_room_assignments", "start_time", server_default=None)

    op.drop_constraint(
        op.f("pk_teacher_room_assignments"),
        "teacher_room_assignments",
        type_="primary",
    )
    op.create_primary_key(
        op.f("pk_teacher_room_assignments"),
        "teacher_room_assignments",
        ["date", "teacher_tax_code", "start_time"],
    )
    op.create_unique_constraint(
        "uq_teacher_room_stretch",
        "teacher_room_assignments",
        ["date", "teacher_tax_code", "start_time", "room_id"],
    )
    op.create_check_constraint(
        op.f("ck_teacher_room_assignments_teacher_room_assignment_time_step"),
        "teacher_room_assignments",
        "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0",
    )

    op.add_column(
        "room_supervisions",
        sa.Column(
            "assignment_start",
            sa.Time(),
            nullable=False,
            server_default=_MIDNIGHT,
        ),
    )
    op.alter_column("room_supervisions", "assignment_start", server_default=None)

    op.create_foreign_key(
        "room_supervisions_assignment_fkey",
        "room_supervisions",
        "teacher_room_assignments",
        ["date", "teacher_tax_code", "assignment_start", "room_id"],
        ["date", "teacher_tax_code", "start_time", "room_id"],
        ondelete="CASCADE",
        onupdate="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "room_supervisions_assignment_fkey",
        "room_supervisions",
        type_="foreignkey",
    )

    # Only the day's first room survives: one room per teacher per day again.
    op.execute(
        """
        DELETE FROM room_supervisions AS shift
        USING teacher_room_assignments AS row
        WHERE row.date = shift.date
          AND row.teacher_tax_code = shift.teacher_tax_code
          AND row.start_time = shift.assignment_start
          AND row.start_time > (
              SELECT min(first.start_time)
              FROM teacher_room_assignments AS first
              WHERE first.date = row.date
                AND first.teacher_tax_code = row.teacher_tax_code
          )
        """,
    )
    op.execute(
        """
        DELETE FROM teacher_room_assignments AS row
        WHERE row.start_time > (
            SELECT min(first.start_time)
            FROM teacher_room_assignments AS first
            WHERE first.date = row.date
              AND first.teacher_tax_code = row.teacher_tax_code
        )
        """,
    )

    op.drop_column("room_supervisions", "assignment_start")

    op.drop_constraint(
        op.f("ck_teacher_room_assignments_teacher_room_assignment_time_step"),
        "teacher_room_assignments",
        type_="check",
    )
    op.drop_constraint(
        "uq_teacher_room_stretch",
        "teacher_room_assignments",
        type_="unique",
    )
    op.drop_constraint(
        op.f("pk_teacher_room_assignments"),
        "teacher_room_assignments",
        type_="primary",
    )
    op.drop_column("teacher_room_assignments", "start_time")
    op.create_primary_key(
        op.f("pk_teacher_room_assignments"),
        "teacher_room_assignments",
        ["date", "teacher_tax_code"],
    )
    op.create_unique_constraint(
        "uq_teacher_room_identity",
        "teacher_room_assignments",
        ["date", "teacher_tax_code", "room_id"],
    )
    op.create_foreign_key(
        "room_supervisions_assignment_fkey",
        "room_supervisions",
        "teacher_room_assignments",
        ["date", "teacher_tax_code", "room_id"],
        ["date", "teacher_tax_code", "room_id"],
        ondelete="CASCADE",
        onupdate="CASCADE",
    )
