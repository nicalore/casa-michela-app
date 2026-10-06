"""Methodological notes

Revision ID: d5a7c3e9f214
Revises: b81e5d0c7a3f
Create Date: 2026-10-05
"""

import sqlalchemy as sa

from alembic import op

revision = "d5a7c3e9f214"
down_revision = "b81e5d0c7a3f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "methodological_notes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=False),
        sa.Column("text", sa.String(2000), nullable=False),
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
            name=op.f("ck_methodological_notes_text_not_blank"),
        ),
        sa.CheckConstraint(
            "text IS NULL OR text = btrim(text)",
            name=op.f("ck_methodological_notes_text_no_surrounding_whitespace"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_methodological_notes_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_methodological_notes_author_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_methodological_notes")),
    )
    op.create_index(
        op.f("ix_methodological_notes_student_tax_code"),
        "methodological_notes",
        ["student_tax_code"],
    )
    op.create_index(
        op.f("ix_methodological_notes_author_tax_code"),
        "methodological_notes",
        ["author_tax_code"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_methodological_notes_author_tax_code"),
        table_name="methodological_notes",
    )
    op.drop_index(
        op.f("ix_methodological_notes_student_tax_code"),
        table_name="methodological_notes",
    )
    op.drop_table("methodological_notes")
