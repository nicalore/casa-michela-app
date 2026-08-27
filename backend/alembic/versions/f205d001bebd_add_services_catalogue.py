"""add services catalogue

Revision ID: f205d001bebd
Revises: 674a015f7bf2
Create Date: 2026-08-04 12:46:26.887944

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "f205d001bebd"
down_revision = "674a015f7bf2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "services",
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=1000), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name=op.f("ck_services_name_not_blank"),
        ),
        sa.CheckConstraint(
            "name IS NULL OR name = btrim(name)",
            name=op.f("ck_services_name_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name=op.f("ck_services_description_not_blank"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR description = btrim(description)",
            name=op.f("ck_services_description_no_surrounding_whitespace"),
        ),
        sa.PrimaryKeyConstraint("name", name=op.f("pk_services")),
    )


def downgrade() -> None:
    op.drop_table("services")
