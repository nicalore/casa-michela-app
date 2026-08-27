"""add teacher services

Revision ID: deff88ef5884
Revises: f205d001bebd
Create Date: 2026-08-04 13:14:18.299539

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "deff88ef5884"
down_revision = "f205d001bebd"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "teacher_services",
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("service_name", sa.String(length=255), nullable=False),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_teacher_services_teacher_tax_code_teachers"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["service_name"],
            ["services.name"],
            name=op.f("fk_teacher_services_service_name_services"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "teacher_tax_code",
            "service_name",
            name=op.f("pk_teacher_services"),
        ),
    )
    # For the reverse lookup (who covers this service); teacher_tax_code already
    # leads the primary key and needs no index.
    op.create_index(
        op.f("ix_teacher_services_service_name"),
        "teacher_services",
        ["service_name"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_teacher_services_service_name"),
        table_name="teacher_services",
    )
    op.drop_table("teacher_services")
