"""student payments

Packages and months bought, lessons settled by the hour; tariff rows of one day
are allowed and follow their ids.

Revision ID: e4c7a9d2b816
Revises: d2b6e8f1c4a7
Create Date: 2026-11-11
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "e4c7a9d2b816"
down_revision = "d2b6e8f1c4a7"
branch_labels = None
depends_on = None

_KIND_VALUES = ("PACKAGE", "MONTH", "HOURS")

_HOURS_KIND_VALUES = ("HOURLY", "OVER_PACKAGE", "OVER_FEE", "WEEKEND_ONLINE")


def upgrade() -> None:
    op.drop_constraint(
        "unique_student_tariff_start",
        "student_tariffs",
        type_="unique",
    )

    postgresql.ENUM(*_KIND_VALUES, name="student_payment_kind_enum").create(
        op.get_bind(),
        checkfirst=True,
    )
    postgresql.ENUM(*_HOURS_KIND_VALUES, name="hours_kind_enum").create(
        op.get_bind(),
        checkfirst=True,
    )

    op.create_table(
        "student_payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column(
            "kind",
            postgresql.ENUM(name="student_payment_kind_enum", create_type=False),
            nullable=False,
        ),
        sa.Column("tariff_id", sa.Integer(), nullable=True),
        sa.Column("month", sa.Date(), nullable=True),
        sa.Column("package_hours", sa.Integer(), nullable=True),
        sa.Column(
            "hours_kind",
            postgresql.ENUM(name="hours_kind_enum", create_type=False),
            nullable=True,
        ),
        sa.Column("cents_per_hour", sa.Integer(), nullable=True),
        sa.Column("amount_cents", sa.Integer(), nullable=False),
        sa.Column("paid_on", sa.Date(), nullable=False),
        sa.Column(
            "payment_method",
            postgresql.ENUM(name="payment_method_enum", create_type=False),
            nullable=False,
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
            name=op.f("ck_student_payments_student_payment_amount_positive"),
        ),
        sa.CheckConstraint(
            "(kind = 'PACKAGE') = (package_hours IS NOT NULL)",
            name=op.f("ck_student_payments_student_payment_hours_only_for_packages"),
        ),
        sa.CheckConstraint(
            "package_hours IS NULL OR package_hours > 0",
            name=op.f("ck_student_payments_student_payment_package_hours_positive"),
        ),
        sa.CheckConstraint(
            "kind = 'HOURS' OR tariff_id IS NOT NULL",
            name=op.f(
                "ck_student_payments_student_payment_package_or_month_has_tariff"
            ),
        ),
        sa.CheckConstraint(
            "kind = 'MONTH' OR month IS NULL",
            name=op.f("ck_student_payments_student_payment_month_only_for_months"),
        ),
        sa.CheckConstraint(
            "(kind = 'HOURS') = (hours_kind IS NOT NULL)",
            name=op.f(
                "ck_student_payments_student_payment_hours_kind_only_for_hours"
            ),
        ),
        sa.CheckConstraint(
            "payment_method_other IS NULL OR payment_method = 'OTHER'",
            name=op.f(
                "ck_student_payments_student_payment_other_requires_other_method"
            ),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_student_payments_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["tariff_id"],
            ["student_tariffs.id"],
            name=op.f("fk_student_payments_tariff_id_student_tariffs"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_student_payments")),
    )
    op.create_index(
        op.f("ix_student_payments_student_tax_code"),
        "student_payments",
        ["student_tax_code"],
    )
    op.create_index(
        op.f("ix_student_payments_tariff_id"),
        "student_payments",
        ["tariff_id"],
    )

    op.create_table(
        "student_payment_lessons",
        sa.Column("payment_id", sa.Integer(), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "minutes > 0",
            name=op.f("ck_student_payment_lessons_minutes_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["payment_id"],
            ["student_payments.id"],
            name=op.f("fk_student_payment_lessons_payment_id_student_payments"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["lesson_id"],
            ["lessons.id"],
            name=op.f("fk_student_payment_lessons_lesson_id_lessons"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "payment_id",
            "lesson_id",
            name=op.f("pk_student_payment_lessons"),
        ),
    )
    op.create_index(
        op.f("ix_student_payment_lessons_lesson_id"),
        "student_payment_lessons",
        ["lesson_id"],
    )


def downgrade() -> None:
    op.drop_table("student_payment_lessons")
    op.drop_table("student_payments")
    postgresql.ENUM(name="hours_kind_enum").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="student_payment_kind_enum").drop(
        op.get_bind(),
        checkfirst=True,
    )

    # Of one day, only the latest row stays.
    op.execute(
        """
        DELETE FROM student_tariffs t
        USING student_tariffs later
        WHERE later.student_tax_code = t.student_tax_code
          AND later.starts_on = t.starts_on
          AND later.id > t.id
        """
    )
    op.create_unique_constraint(
        "unique_student_tariff_start",
        "student_tariffs",
        ["student_tax_code", "starts_on"],
    )
