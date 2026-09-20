"""Not preferred teachers belong to the student

Revision ID: 105e64d74fc6
Revises: a4e1c7d92b05
Create Date: 2026-09-13
"""

from typing import Final

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "105e64d74fc6"
down_revision = "a4e1c7d92b05"
branch_labels = None
depends_on = None

_TEACHER_PREFERENCE_TYPE_ENUM: Final[str] = "teacher_preference_type_enum"
_TEACHER_PREFERENCE_TYPES: Final[tuple[str, ...]] = ("PREFERRED", "NOT_PREFERRED")

_OLD_TABLE: Final[str] = "booking_teacher_preferences"
_NEW_TABLE: Final[str] = "booking_preferred_teachers"

# Constraint names embed the table name: a plain rename would trip autogenerate.
_RENAMED_CONSTRAINTS: Final[tuple[tuple[str, str], ...]] = (
    (f"pk_{_OLD_TABLE}", f"pk_{_NEW_TABLE}"),
    (f"fk_{_OLD_TABLE}_booking_id_bookings", f"fk_{_NEW_TABLE}_booking_id_bookings"),
    (
        f"fk_{_OLD_TABLE}_teacher_tax_code_teachers",
        f"fk_{_NEW_TABLE}_teacher_tax_code_teachers",
    ),
)

_RENAMED_INDEX: Final[tuple[str, str]] = (
    f"ix_{_OLD_TABLE}_teacher_tax_code",
    f"ix_{_NEW_TABLE}_teacher_tax_code",
)

# One open row per (pupil, teacher) named on any booking, from the first such lesson.
_COPY_TO_STUDENTS: Final[str] = """
    INSERT INTO student_not_preferred_teachers
        (student_tax_code, teacher_tax_code, valid_from)
    SELECT presences.student_tax_code,
           booking_teacher_preferences.teacher_tax_code,
           MIN(presences.date)
    FROM booking_teacher_preferences
    JOIN bookings ON bookings.id = booking_teacher_preferences.booking_id
    JOIN presences ON presences.id = bookings.presence_id
    WHERE booking_teacher_preferences.preference_type = 'NOT_PREFERRED'
    GROUP BY presences.student_tax_code,
             booking_teacher_preferences.teacher_tax_code
"""


def _rename(table: str, pairs: tuple[tuple[str, str], ...]) -> None:
    for old_name, new_name in pairs:
        op.execute(f"ALTER TABLE {table} RENAME CONSTRAINT {old_name} TO {new_name}")


def upgrade() -> None:
    bind = op.get_bind()

    op.create_table(
        "student_not_preferred_teachers",
        sa.Column("student_tax_code", sa.String(length=16), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("valid_from", sa.Date(), nullable=False),
        sa.Column("valid_to", sa.Date(), nullable=True),
        sa.CheckConstraint(
            "valid_to IS NULL OR valid_to > valid_from",
            name=op.f("ck_student_not_preferred_teachers_validity_ends_after_start"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_student_not_preferred_teachers_student_tax_code_students"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_student_not_preferred_teachers_teacher_tax_code_teachers"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "student_tax_code",
            "teacher_tax_code",
            "valid_from",
            name=op.f("pk_student_not_preferred_teachers"),
        ),
    )
    op.create_index(
        op.f("ix_student_not_preferred_teachers_teacher_tax_code"),
        "student_not_preferred_teachers",
        ["teacher_tax_code"],
        unique=False,
    )
    op.create_index(
        "ux_student_not_preferred_teacher_open",
        "student_not_preferred_teachers",
        ["student_tax_code", "teacher_tax_code"],
        unique=True,
        postgresql_where=sa.text("valid_to IS NULL"),
    )

    op.execute(_COPY_TO_STUDENTS)
    op.execute(f"DELETE FROM {_OLD_TABLE} WHERE preference_type = 'NOT_PREFERRED'")

    op.drop_column(_OLD_TABLE, "preference_type")
    postgresql.ENUM(name=_TEACHER_PREFERENCE_TYPE_ENUM).drop(bind, checkfirst=True)

    op.rename_table(_OLD_TABLE, _NEW_TABLE)
    _rename(_NEW_TABLE, _RENAMED_CONSTRAINTS)
    op.execute(f"ALTER INDEX {_RENAMED_INDEX[0]} RENAME TO {_RENAMED_INDEX[1]}")


# The pupils' lists no longer map to bookings and are lost on the way down.
def downgrade() -> None:
    bind = op.get_bind()

    op.execute(f"ALTER INDEX {_RENAMED_INDEX[1]} RENAME TO {_RENAMED_INDEX[0]}")
    _rename(_NEW_TABLE, tuple((new, old) for old, new in _RENAMED_CONSTRAINTS))
    op.rename_table(_NEW_TABLE, _OLD_TABLE)

    postgresql.ENUM(
        *_TEACHER_PREFERENCE_TYPES,
        name=_TEACHER_PREFERENCE_TYPE_ENUM,
    ).create(bind, checkfirst=True)
    op.add_column(
        _OLD_TABLE,
        sa.Column(
            "preference_type",
            postgresql.ENUM(name=_TEACHER_PREFERENCE_TYPE_ENUM, create_type=False),
            nullable=False,
            server_default="PREFERRED",
        ),
    )
    op.alter_column(_OLD_TABLE, "preference_type", server_default=None)

    op.drop_index(
        "ux_student_not_preferred_teacher_open",
        table_name="student_not_preferred_teachers",
    )
    op.drop_index(
        op.f("ix_student_not_preferred_teachers_teacher_tax_code"),
        table_name="student_not_preferred_teachers",
    )
    op.drop_table("student_not_preferred_teachers")
