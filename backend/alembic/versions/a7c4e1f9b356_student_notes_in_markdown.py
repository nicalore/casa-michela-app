"""Technical and methodological notes in Markdown, with their images

Revision ID: a7c4e1f9b356
Revises: d3e9a6c1b742
Create Date: 2026-10-11
"""

import re

import sqlalchemy as sa

from alembic import op

revision = "a7c4e1f9b356"
down_revision = "d3e9a6c1b742"
branch_labels = None
depends_on = None

_TABLES = ("technical_notes", "methodological_notes")

# Any ASCII punctuation may be escaped; these would otherwise format the text.
_SPECIAL = re.compile(r"([\\`*_{}\[\]()#+\-.!<>~|&])")


# Plain text read as Markdown: each line a paragraph, every mark taken literally.
def _markdown(text: str) -> str:
    lines = (line.strip() for line in text.splitlines())

    return "\n\n".join(_SPECIAL.sub(r"\\\1", line) for line in lines if line)


def upgrade() -> None:
    op.create_table(
        "student_note_images",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("technical_note_id", sa.Integer(), nullable=True),
        sa.Column("methodological_note_id", sa.Integer(), nullable=True),
        sa.Column("image_key", sa.String(36), nullable=False),
        sa.Column("content_type", sa.String(255), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column("content", sa.LargeBinary(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "num_nonnulls(technical_note_id, methodological_note_id) = 1",
            name=op.f("ck_student_note_images_one_note"),
        ),
        sa.CheckConstraint(
            "size >= 0",
            name=op.f("ck_student_note_images_size_not_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["technical_note_id"],
            ["technical_notes.id"],
            name=op.f("fk_student_note_images_technical_note_id_technical_notes"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["methodological_note_id"],
            ["methodological_notes.id"],
            name=op.f(
                "fk_student_note_images_methodological_note_id_methodological_notes"
            ),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_student_note_images")),
        sa.UniqueConstraint(
            "technical_note_id",
            "image_key",
            name=op.f("uq_student_note_images_technical_note_id"),
        ),
        sa.UniqueConstraint(
            "methodological_note_id",
            "image_key",
            name=op.f("uq_student_note_images_methodological_note_id"),
        ),
    )
    op.create_index(
        op.f("ix_student_note_images_technical_note_id"),
        "student_note_images",
        ["technical_note_id"],
    )
    op.create_index(
        op.f("ix_student_note_images_methodological_note_id"),
        "student_note_images",
        ["methodological_note_id"],
    )

    connection = op.get_bind()

    for table in _TABLES:
        op.alter_column(
            table,
            "text",
            type_=sa.String(10000),
            existing_type=sa.String(2000),
            existing_nullable=False,
        )

        notes = connection.execute(sa.text(f"SELECT id, text FROM {table}"))

        for note_id, text in notes.all():
            connection.execute(
                sa.text(f"UPDATE {table} SET text = :text WHERE id = :id"),
                {"text": _markdown(text), "id": note_id},
            )


# The Markdown stays: only what the old columns can hold is kept.
def downgrade() -> None:
    for table in _TABLES:
        op.alter_column(
            table,
            "text",
            type_=sa.String(2000),
            existing_type=sa.String(10000),
            existing_nullable=False,
            postgresql_using="btrim(left(text, 2000))",
        )

    op.drop_index(
        op.f("ix_student_note_images_methodological_note_id"),
        table_name="student_note_images",
    )
    op.drop_index(
        op.f("ix_student_note_images_technical_note_id"),
        table_name="student_note_images",
    )
    op.drop_table("student_note_images")
