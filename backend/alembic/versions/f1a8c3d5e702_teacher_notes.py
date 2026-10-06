"""Teacher notes

Revision ID: f1a8c3d5e702
Revises: e9c4b2f7a618
Create Date: 2026-10-05
"""

import sqlalchemy as sa

from alembic import op

revision = "f1a8c3d5e702"
down_revision = "e9c4b2f7a618"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "teacher_notes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=True),
        sa.Column("lesson_date", sa.Date(), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("text", sa.String(2000), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(text)) > 0",
            name=op.f("ck_teacher_notes_text_not_blank"),
        ),
        sa.CheckConstraint(
            "length(trim(subject)) > 0",
            name=op.f("ck_teacher_notes_subject_not_blank"),
        ),
        sa.CheckConstraint(
            "text IS NULL OR text = btrim(text)",
            name=op.f("ck_teacher_notes_text_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "subject IS NULL OR subject = btrim(subject)",
            name=op.f("ck_teacher_notes_subject_no_surrounding_whitespace"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_teacher_notes_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_teacher_notes_author_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["lesson_id"],
            ["lessons.id"],
            name=op.f("fk_teacher_notes_lesson_id_lessons"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_teacher_notes")),
    )

    for column in ("student_tax_code", "author_tax_code", "lesson_id"):
        op.create_index(
            op.f(f"ix_teacher_notes_{column}"),
            "teacher_notes",
            [column],
        )


def downgrade() -> None:
    for column in ("lesson_id", "author_tax_code", "student_tax_code"):
        op.drop_index(op.f(f"ix_teacher_notes_{column}"), table_name="teacher_notes")

    op.drop_table("teacher_notes")
