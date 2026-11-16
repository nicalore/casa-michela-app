"""membership fees

Revision ID: b4d9e1f7c362
Revises: f8c3e5a2d917
Create Date: 2026-11-15
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "b4d9e1f7c362"
down_revision = "f8c3e5a2d917"
branch_labels = None
depends_on = None

_KIND_VALUES = ("MEMBERSHIP", "INSURANCE")


def upgrade() -> None:
    postgresql.ENUM(*_KIND_VALUES, name="membership_fee_kind_enum").create(
        op.get_bind(),
        checkfirst=True,
    )

    op.create_table(
        "membership_fees",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("member_tax_code", sa.String(16), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column(
            "kind",
            postgresql.ENUM(name="membership_fee_kind_enum", create_type=False),
            nullable=False,
        ),
        sa.Column("amount_cents", sa.Integer(), nullable=False),
        sa.Column("paid_on", sa.Date(), nullable=True),
        sa.Column(
            "payment_method",
            postgresql.ENUM(name="payment_method_enum", create_type=False),
            nullable=True,
        ),
        sa.Column("payment_method_other", sa.String(255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount_cents > 0",
            name=op.f("ck_membership_fees_membership_fee_amount_positive"),
        ),
        sa.CheckConstraint(
            "(paid_on IS NULL) = (payment_method IS NULL)",
            name=op.f("ck_membership_fees_membership_fee_paid_with_method"),
        ),
        sa.CheckConstraint(
            "payment_method_other IS NULL OR payment_method = 'OTHER'",
            name=op.f("ck_membership_fees_membership_fee_other_requires_other_method"),
        ),
        sa.ForeignKeyConstraint(
            ["member_tax_code"],
            ["members.tax_code"],
            name=op.f("fk_membership_fees_member_tax_code_members"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_membership_fees")),
        sa.UniqueConstraint(
            "member_tax_code",
            "year",
            "kind",
            name="uq_membership_fee_member_year_kind",
        ),
    )
    op.create_index(
        op.f("ix_membership_fees_member_tax_code"),
        "membership_fees",
        ["member_tax_code"],
    )


def downgrade() -> None:
    op.drop_table("membership_fees")
    postgresql.ENUM(name="membership_fee_kind_enum").drop(
        op.get_bind(),
        checkfirst=True,
    )
