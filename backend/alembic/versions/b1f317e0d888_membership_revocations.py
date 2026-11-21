"""Cessation form details of revoked memberships

Revision ID: b1f317e0d888
Revises: f3a8c1d6b207
Create Date: 2026-11-21
"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "b1f317e0d888"
down_revision = "f3a8c1d6b207"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "membership_revocations"

_GUARDIAN_INDEX: Final[str] = f"ix_{_TABLE}_guardian_tax_code"

_TEXT_COLUMNS: Final[tuple[str, ...]] = (
    "reason",
    "minutes_number",
    "other_ground",
    "protocol_number",
    "card_number",
)


def _ground(name: str) -> sa.Column:
    return sa.Column(name, sa.Boolean(), server_default="false", nullable=False)


def upgrade() -> None:
    op.create_table(
        _TABLE,
        sa.Column("membership_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=100), nullable=True),
        sa.Column("resolution_date", sa.Date(), nullable=True),
        sa.Column("minutes_number", sa.String(length=10), nullable=True),
        _ground("ground_breach"),
        _ground("ground_conduct"),
        _ground("ground_harm"),
        _ground("ground_other"),
        sa.Column("other_ground", sa.String(length=60), nullable=True),
        sa.Column("charged_on", sa.Date(), nullable=True),
        sa.Column("protocol_number", sa.String(length=10), nullable=True),
        sa.Column("card_number", sa.String(length=20), nullable=True),
        sa.Column("guardian_tax_code", sa.String(length=16), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["membership_id"],
            ["memberships.id"],
            name=op.f(f"fk_{_TABLE}_membership_id_memberships"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["guardian_tax_code"],
            ["people.tax_code"],
            name=op.f(f"fk_{_TABLE}_guardian_tax_code_people"),
            onupdate="CASCADE",
            ondelete="SET NULL",
        ),
        sa.CheckConstraint(
            "ground_other = (other_ground IS NOT NULL)",
            name=op.f(f"ck_{_TABLE}_other_ground_with_its_box"),
        ),
        sa.CheckConstraint(
            "charged_on IS NULL OR resolution_date IS NULL "
            "OR charged_on <= resolution_date",
            name=op.f(f"ck_{_TABLE}_charged_before_resolution"),
        ),
        *(
            sa.CheckConstraint(
                f"{column} IS NULL OR length(trim({column})) > 0",
                name=op.f(f"ck_{_TABLE}_{column}_not_blank"),
            )
            for column in _TEXT_COLUMNS
        ),
        *(
            sa.CheckConstraint(
                f"{column} IS NULL OR {column} = btrim({column})",
                name=op.f(f"ck_{_TABLE}_{column}_no_surrounding_whitespace"),
            )
            for column in _TEXT_COLUMNS
        ),
        sa.PrimaryKeyConstraint("membership_id", name=op.f(f"pk_{_TABLE}")),
    )

    op.create_index(op.f(_GUARDIAN_INDEX), _TABLE, ["guardian_tax_code"])


def downgrade() -> None:
    op.drop_index(op.f(_GUARDIAN_INDEX), table_name=_TABLE)
    op.drop_table(_TABLE)
