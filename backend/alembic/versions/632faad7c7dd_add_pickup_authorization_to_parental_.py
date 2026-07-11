"""Add pickup authorization to parental responsibilities

Revision ID: 632faad7c7dd
Revises: 0d17f8e553a3
Create Date: 2026-07-11 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "632faad7c7dd"
down_revision = "0d17f8e553a3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "parental_responsibilities",
        sa.Column(
            "authorized_pickup",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
    )
    op.add_column(
        "parental_responsibilities",
        sa.Column(
            "pickup_restriction_reason",
            sa.String(length=500),
            nullable=True,
        ),
    )
    op.create_check_constraint(
        "pickup_restriction_reason_not_blank",
        "parental_responsibilities",
        "pickup_restriction_reason IS NULL OR length(trim(pickup_restriction_reason)) > 0",
    )
    op.create_check_constraint(
        "pickup_restriction_reason_requires_not_authorized",
        "parental_responsibilities",
        "authorized_pickup = false OR pickup_restriction_reason IS NULL",
    )
    op.create_check_constraint(
        "pickup_restriction_reason_no_surrounding_whitespace",
        "parental_responsibilities",
        "pickup_restriction_reason IS NULL OR pickup_restriction_reason = btrim(pickup_restriction_reason)",
    )


def downgrade() -> None:
    op.drop_constraint(
        "pickup_restriction_reason_no_surrounding_whitespace",
        "parental_responsibilities",
        type_="check",
    )
    op.drop_constraint(
        "pickup_restriction_reason_requires_not_authorized",
        "parental_responsibilities",
        type_="check",
    )
    op.drop_constraint(
        "pickup_restriction_reason_not_blank",
        "parental_responsibilities",
        type_="check",
    )
    op.drop_column("parental_responsibilities", "pickup_restriction_reason")
    op.drop_column("parental_responsibilities", "authorized_pickup")