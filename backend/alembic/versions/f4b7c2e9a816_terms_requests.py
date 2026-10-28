"""IT managers ask everyone to accept the legal documents again; acceptances kept

Revision ID: f4b7c2e9a816
Revises: e3099f3b6957
Create Date: 2026-10-28
"""

import sqlalchemy as sa

from alembic import op

revision = "f4b7c2e9a816"
down_revision = "e3099f3b6957"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "terms_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("author_tax_code", sa.String(16), nullable=True),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_terms_requests_author_tax_code_people"),
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_terms_requests")),
    )
    op.create_index(
        op.f("ix_terms_requests_requested_at"),
        "terms_requests",
        ["requested_at"],
    )

    op.create_table(
        "terms_acceptances",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(16), nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_terms_acceptances_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_terms_acceptances")),
    )
    op.create_index(
        op.f("ix_terms_acceptances_account_tax_code"),
        "terms_acceptances",
        ["account_tax_code"],
    )

    # Until now only the first acceptance was kept.
    op.execute(
        "INSERT INTO terms_acceptances (account_tax_code, accepted_at) "
        "SELECT tax_code, terms_accepted_at FROM accounts "
        "WHERE terms_accepted_at IS NOT NULL",
    )


def downgrade() -> None:
    op.drop_table("terms_acceptances")
    op.drop_table("terms_requests")
