"""What each pupil pays for Aiuto Compiti, from a day on

Revision ID: d8b3f6a2c915
Revises: c9e1f4a7b3d2
Create Date: 2026-11-11
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "d8b3f6a2c915"
down_revision = "c9e1f4a7b3d2"
branch_labels = None
depends_on = None

_KIND_VALUES = ("HOURLY", "PACKAGE", "MONTHLY")

_OLD_VALUES = (
    "PRIMARY_MONTHLY",
    "MIDDLE_HOURLY",
    "MIDDLE_PACKAGE",
    "HIGH_HOURLY",
    "HIGH_PACKAGE",
)

# The enrolment form's rates, in force from 1 September 2026.
_FORM_RATES = (
    ("PRIMARY_MONTHLY", "MONTHLY", 17000, None),
    ("MIDDLE_HOURLY", "HOURLY", 1300, None),
    ("MIDDLE_PACKAGE", "PACKAGE", 21500, 18),
    ("HIGH_HOURLY", "HOURLY", 1400, None),
    ("HIGH_PACKAGE", "PACKAGE", 26000, 20),
)

_RATES_IN_FORCE_FROM = "2026-09-01"


def _rates_table() -> str:
    rows = ", ".join(
        f"('{old}', '{kind}', {cents}, {hours if hours is not None else 'NULL'})"
        for old, kind, cents, hours in _FORM_RATES
    )

    return f"(VALUES {rows}) AS rates(old, kind, cents, hours)"


def upgrade() -> None:
    kind_enum = postgresql.ENUM(*_KIND_VALUES, name="tariff_kind_enum")
    kind_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "student_tariffs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column(
            "kind",
            postgresql.ENUM(name="tariff_kind_enum", create_type=False),
            nullable=False,
        ),
        sa.Column("starts_on", sa.Date(), nullable=False),
        sa.Column("amount_cents", sa.Integer(), nullable=False),
        sa.Column("package_hours", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "amount_cents > 0",
            name=op.f("ck_student_tariffs_student_tariff_amount_positive"),
        ),
        sa.CheckConstraint(
            "(kind = 'PACKAGE') = (package_hours IS NOT NULL)",
            name=op.f("ck_student_tariffs_student_tariff_hours_only_for_packages"),
        ),
        sa.CheckConstraint(
            "package_hours IS NULL OR package_hours > 0",
            name=op.f("ck_student_tariffs_student_tariff_hours_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_student_tariffs_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_student_tariffs")),
        sa.UniqueConstraint(
            "student_tax_code",
            "starts_on",
            name="unique_student_tariff_start",
        ),
    )
    op.create_index(
        op.f("ix_student_tariffs_student_tax_code"),
        "student_tariffs",
        ["student_tax_code"],
    )

    # The chosen cell at the form's rates, from 1 September or the later start of
    # the membership running then.
    op.execute(
        f"""
        INSERT INTO student_tariffs
            (student_tax_code, kind, starts_on, amount_cents, package_hours)
        SELECT
            s.tax_code,
            rates.kind::tariff_kind_enum,
            GREATEST(
                DATE '{_RATES_IN_FORCE_FROM}',
                COALESCE(
                    (
                        SELECT MIN(m.start_date)
                        FROM memberships m
                        WHERE m.member_tax_code = s.tax_code
                          AND m.end_date >= DATE '{_RATES_IN_FORCE_FROM}'
                    ),
                    DATE '{_RATES_IN_FORCE_FROM}'
                )
            ),
            rates.cents,
            rates.hours
        FROM students s
        JOIN {_rates_table()} ON rates.old = s.homework_tariff::text
        """
    )

    op.drop_column("students", "homework_tariff")
    postgresql.ENUM(name="homework_tariff_enum").drop(op.get_bind(), checkfirst=True)


def downgrade() -> None:
    old_enum = postgresql.ENUM(*_OLD_VALUES, name="homework_tariff_enum")
    old_enum.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "students",
        sa.Column("homework_tariff", old_enum, nullable=True),
    )

    # Only a latest tariff at the form's rates has a cell to go back to.
    op.execute(
        f"""
        UPDATE students s
        SET homework_tariff = rates.old::homework_tariff_enum
        FROM (
            SELECT DISTINCT ON (student_tax_code)
                student_tax_code, kind, amount_cents, package_hours
            FROM student_tariffs
            ORDER BY student_tax_code, starts_on DESC
        ) latest
        JOIN {_rates_table()}
          ON rates.kind = latest.kind::text
         AND rates.cents = latest.amount_cents
         AND rates.hours IS NOT DISTINCT FROM latest.package_hours
        WHERE latest.student_tax_code = s.tax_code
        """
    )

    op.drop_table("student_tariffs")
    postgresql.ENUM(name="tariff_kind_enum").drop(op.get_bind(), checkfirst=True)
