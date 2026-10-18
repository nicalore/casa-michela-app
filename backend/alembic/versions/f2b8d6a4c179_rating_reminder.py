"""The president reminded to update a new teacher's rating two weeks on

Revision ID: f2b8d6a4c179
Revises: d9f3b7c5a468
Create Date: 2026-10-18
"""

import sqlalchemy as sa

from alembic import op

revision = "f2b8d6a4c179"
down_revision = "d9f3b7c5a468"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'RATING_REMINDER'"
        )

    op.add_column(
        "notifications",
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=True),
    )
    op.create_foreign_key(
        op.f("fk_notifications_teacher_tax_code_people"),
        "notifications",
        "people",
        ["teacher_tax_code"],
        ["tax_code"],
        ondelete="CASCADE",
        onupdate="CASCADE",
    )
    op.create_index(
        op.f("ix_notifications_teacher_tax_code"),
        "notifications",
        ["teacher_tax_code"],
    )
    op.create_index(
        "uq_notifications_rating_reminder",
        "notifications",
        ["account_tax_code", "teacher_tax_code"],
        unique=True,
        postgresql_where=sa.text("kind = 'RATING_REMINDER'"),
    )


# Postgres cannot drop an enum value: the rows of the new kind go instead.
def downgrade() -> None:
    op.drop_index("uq_notifications_rating_reminder", table_name="notifications")
    op.drop_index(
        op.f("ix_notifications_teacher_tax_code"),
        table_name="notifications",
    )
    op.drop_constraint(
        op.f("fk_notifications_teacher_tax_code_people"),
        "notifications",
        type_="foreignkey",
    )
    op.drop_column("notifications", "teacher_tax_code")
    op.execute("DELETE FROM notifications WHERE kind = 'RATING_REMINDER'")
    op.execute(
        "DELETE FROM muted_notification_kinds WHERE kind = 'RATING_REMINDER'"
    )
