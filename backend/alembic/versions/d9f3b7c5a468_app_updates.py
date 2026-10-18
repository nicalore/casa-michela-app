"""App updates written by the IT managers, their images and who has read them

Revision ID: d9f3b7c5a468
Revises: c8e2a6f4b357
Create Date: 2026-10-18
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "d9f3b7c5a468"
down_revision = "c8e2a6f4b357"
branch_labels = None
depends_on = None

_ROLE = postgresql.ENUM(
    "ADMIN",
    "TEACHER",
    "PSYCHOLOGIST",
    "PARENT",
    "STUDENT",
    name="app_update_role_enum",
    create_type=False,
)


def _text_checks(table: str, *columns: str) -> list[sa.CheckConstraint]:
    checks: list[sa.CheckConstraint] = []

    for column in columns:
        checks.append(
            sa.CheckConstraint(
                f"length(trim({column})) > 0",
                name=op.f(f"ck_{table}_{column}_not_blank"),
            )
        )
        checks.append(
            sa.CheckConstraint(
                f"{column} IS NULL OR {column} = btrim({column})",
                name=op.f(f"ck_{table}_{column}_no_surrounding_whitespace"),
            )
        )

    return checks


def upgrade() -> None:
    _ROLE.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "app_updates",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=False),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("message", sa.String(20000), nullable=False),
        sa.Column("version", sa.String(20), nullable=False),
        sa.Column("recipients", postgresql.ARRAY(_ROLE), nullable=False),
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
        *_text_checks("app_updates", "title", "message", "version"),
        sa.CheckConstraint(
            "cardinality(recipients) > 0",
            name=op.f("ck_app_updates_recipients_not_empty"),
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_app_updates_author_tax_code_people"),
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_app_updates")),
    )
    op.create_index(
        op.f("ix_app_updates_author_tax_code"),
        "app_updates",
        ["author_tax_code"],
    )

    op.create_table(
        "app_update_images",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("update_id", sa.Integer(), nullable=False),
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
            "size >= 0",
            name=op.f("ck_app_update_images_size_not_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["update_id"],
            ["app_updates.id"],
            name=op.f("fk_app_update_images_update_id_app_updates"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_app_update_images")),
        sa.UniqueConstraint(
            "update_id",
            "image_key",
            name=op.f("uq_app_update_images_update_id"),
        ),
    )
    op.create_index(
        op.f("ix_app_update_images_update_id"),
        "app_update_images",
        ["update_id"],
    )

    op.create_table(
        "app_update_reads",
        sa.Column("update_id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["update_id"],
            ["app_updates.id"],
            name=op.f("fk_app_update_reads_update_id_app_updates"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_app_update_reads_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "update_id",
            "account_tax_code",
            name=op.f("pk_app_update_reads"),
        ),
    )


def downgrade() -> None:
    op.drop_table("app_update_reads")
    op.drop_index(
        op.f("ix_app_update_images_update_id"),
        table_name="app_update_images",
    )
    op.drop_table("app_update_images")
    op.drop_index(op.f("ix_app_updates_author_tax_code"), table_name="app_updates")
    op.drop_table("app_updates")
    _ROLE.drop(op.get_bind(), checkfirst=True)
