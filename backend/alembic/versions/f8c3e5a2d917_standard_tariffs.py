"""standard tariffs and annual fees

Revision ID: f8c3e5a2d917
Revises: c6e2a8f4d913
Create Date: 2026-11-15
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "f8c3e5a2d917"
down_revision = "c6e2a8f4d913"
branch_labels = None
depends_on = None

# The enrolment form's rates; the monthly fees of middle and high school and the
# primary hourly rate (hours over the fee) are the ones the app already used.
_TARIFFS = (
    ("PRIMARY_SCHOOL", False, 1300, False, None, None, True, 17000, 1800),
    ("MIDDLE_SCHOOL", True, 1300, True, 21500, 18, True, 20000, 1800),
    ("HIGH_SCHOOL", True, 1400, True, 26000, 20, True, 25000, 1800),
)

_MEMBERSHIP_CENTS = 1500

_INSURANCE_CENTS = 2000


def upgrade() -> None:
    standard_tariffs = op.create_table(
        "standard_tariffs",
        sa.Column(
            "level",
            postgresql.ENUM(name="education_level_enum", create_type=False),
            primary_key=True,
        ),
        sa.Column("hourly_enabled", sa.Boolean(), nullable=False),
        sa.Column("hourly_cents", sa.Integer(), nullable=False),
        sa.Column("package_enabled", sa.Boolean(), nullable=False),
        sa.Column("package_cents", sa.Integer(), nullable=True),
        sa.Column("package_hours", sa.Integer(), nullable=True),
        sa.Column("monthly_enabled", sa.Boolean(), nullable=False),
        sa.Column("monthly_cents", sa.Integer(), nullable=True),
        sa.Column("weekend_online_cents", sa.Integer(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "NOT package_enabled OR package_cents IS NOT NULL",
            name=op.f("ck_standard_tariffs_standard_tariff_package_priced"),
        ),
        sa.CheckConstraint(
            "NOT monthly_enabled OR monthly_cents IS NOT NULL",
            name=op.f("ck_standard_tariffs_standard_tariff_monthly_priced"),
        ),
        sa.CheckConstraint(
            "(package_cents IS NULL) = (package_hours IS NULL)",
            name=op.f("ck_standard_tariffs_standard_tariff_package_hours"),
        ),
        sa.CheckConstraint(
            "hourly_enabled OR package_enabled OR monthly_enabled",
            name=op.f("ck_standard_tariffs_standard_tariff_one_enabled"),
        ),
        sa.CheckConstraint(
            "hourly_cents > 0 "
            "AND (package_cents IS NULL OR package_cents > 0) "
            "AND (package_hours IS NULL OR package_hours > 0) "
            "AND (monthly_cents IS NULL OR monthly_cents > 0) "
            "AND weekend_online_cents > 0",
            name=op.f("ck_standard_tariffs_standard_tariff_amounts_positive"),
        ),
    )
    annual_fees = op.create_table(
        "annual_fees",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column("membership_cents", sa.Integer(), nullable=False),
        sa.Column("insurance_cents", sa.Integer(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "id = 1",
            name=op.f("ck_annual_fees_annual_fees_single_row"),
        ),
        sa.CheckConstraint(
            "membership_cents > 0 AND insurance_cents > 0",
            name=op.f("ck_annual_fees_annual_fees_positive"),
        ),
    )
    op.bulk_insert(
        standard_tariffs,
        [
            {
                "level": level,
                "hourly_enabled": hourly_on,
                "hourly_cents": hourly,
                "package_enabled": package_on,
                "package_cents": package,
                "package_hours": hours,
                "monthly_enabled": monthly_on,
                "monthly_cents": monthly,
                "weekend_online_cents": weekend,
            }
            for (
                level,
                hourly_on,
                hourly,
                package_on,
                package,
                hours,
                monthly_on,
                monthly,
                weekend,
            ) in _TARIFFS
        ],
    )
    op.bulk_insert(
        annual_fees,
        [
            {
                "id": 1,
                "membership_cents": _MEMBERSHIP_CENTS,
                "insurance_cents": _INSURANCE_CENTS,
            }
        ],
    )


def downgrade() -> None:
    op.drop_table("annual_fees")
    op.drop_table("standard_tariffs")
