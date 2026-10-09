"""Notices

Revision ID: c4f7a2d9e816
Revises: b8d2e6f4a913
Create Date: 2026-10-07
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "c4f7a2d9e816"
down_revision = "b8d2e6f4a913"
branch_labels = None
depends_on = None

_ROLE = postgresql.ENUM(
    "ADMIN",
    "TEACHER",
    "PSYCHOLOGIST",
    "PARENT",
    "STUDENT",
    "COURSE_PARTICIPANT",
    "MEMBER",
    name="notice_role_enum",
    create_type=False,
)


def upgrade() -> None:
    _ROLE.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "notices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=False),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("message", sa.String(20000), nullable=False),
        sa.Column("recipients", postgresql.ARRAY(_ROLE), nullable=False),
        sa.Column("recipient_count", sa.Integer(), nullable=False),
        sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True),
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
            "length(trim(title)) > 0",
            name=op.f("ck_notices_title_not_blank"),
        ),
        sa.CheckConstraint(
            "length(trim(message)) > 0",
            name=op.f("ck_notices_message_not_blank"),
        ),
        sa.CheckConstraint(
            "title IS NULL OR title = btrim(title)",
            name=op.f("ck_notices_title_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "message IS NULL OR message = btrim(message)",
            name=op.f("ck_notices_message_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "cardinality(recipients) > 0",
            name=op.f("ck_notices_recipients_not_empty"),
        ),
        sa.CheckConstraint(
            "recipient_count >= 0",
            name=op.f("ck_notices_recipient_count_not_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_notices_author_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notices")),
    )
    op.create_index(
        op.f("ix_notices_author_tax_code"),
        "notices",
        ["author_tax_code"],
    )

    op.create_table(
        "notice_files",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("notice_id", sa.Integer(), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(255), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column("image_key", sa.String(36), nullable=True),
        sa.Column("content", sa.LargeBinary(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(file_name)) > 0",
            name=op.f("ck_notice_files_file_name_not_blank"),
        ),
        sa.CheckConstraint(
            "size >= 0",
            name=op.f("ck_notice_files_size_not_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["notice_id"],
            ["notices.id"],
            name=op.f("fk_notice_files_notice_id_notices"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notice_files")),
        sa.UniqueConstraint(
            "notice_id",
            "image_key",
            name=op.f("uq_notice_files_notice_id"),
        ),
    )
    op.create_index(
        op.f("ix_notice_files_notice_id"),
        "notice_files",
        ["notice_id"],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_notice_files_notice_id"), table_name="notice_files")
    op.drop_table("notice_files")
    op.drop_index(op.f("ix_notices_author_tax_code"), table_name="notices")
    op.drop_table("notices")
    _ROLE.drop(op.get_bind(), checkfirst=True)
