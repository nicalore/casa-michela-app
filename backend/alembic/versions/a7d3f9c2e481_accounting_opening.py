"""accounting opening

Money from 16 November 2026; teachers and pupils collaborating now are listed
for the initial set-up of how they stood on the 15th.

Revision ID: a7d3f9c2e481
Revises: e5b2d8c14a67
Create Date: 2026-11-16
"""

import sqlalchemy as sa

from alembic import op

revision = "a7d3f9c2e481"
down_revision = "e5b2d8c14a67"
branch_labels = None
depends_on = None

# Enrolled today on their newest membership, begun by the 15th, and collaborating.
_ACTIVE = """
    JOIN members m ON m.tax_code = r.tax_code
    WHERE m.collaborating_active
      AND EXISTS (
        SELECT 1 FROM memberships ms
        WHERE ms.member_tax_code = m.tax_code
          AND ms.revocation = 'NO'
          AND ms.start_date <= DATE '2026-11-15'
          AND ms.end_date + ms.renewal_period_days
              > (now() AT TIME ZONE 'Europe/Rome')::date
          AND NOT EXISTS (
            SELECT 1 FROM memberships newer
            WHERE newer.member_tax_code = ms.member_tax_code
              AND newer.year > ms.year
          )
      )
"""


def _people() -> list[sa.Column]:
    return [
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "confirmed_by_tax_code",
            sa.String(16),
            sa.ForeignKey(
                "people.tax_code",
                ondelete="SET NULL",
                onupdate="CASCADE",
            ),
            nullable=True,
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "accounting_openings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("money_from", sa.Date(), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "closed_by_tax_code",
            sa.String(16),
            sa.ForeignKey(
                "people.tax_code",
                ondelete="SET NULL",
                onupdate="CASCADE",
            ),
            nullable=True,
        ),
        sa.CheckConstraint("id = 1", name="accounting_opening_single"),
    )
    op.create_table(
        "teacher_openings",
        sa.Column(
            "tax_code",
            sa.String(16),
            sa.ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
            primary_key=True,
        ),
        sa.Column("gross", sa.Numeric(10, 2), nullable=True),
        *_people(),
        sa.CheckConstraint(
            "gross IS NULL OR gross >= 0",
            name="teacher_opening_gross_not_negative",
        ),
        sa.CheckConstraint(
            "confirmed_at IS NOT NULL OR gross IS NULL",
            name="teacher_opening_gross_once_confirmed",
        ),
    )
    op.create_table(
        "pupil_openings",
        sa.Column(
            "tax_code",
            sa.String(16),
            sa.ForeignKey(
                "students.tax_code",
                ondelete="CASCADE",
                onupdate="CASCADE",
            ),
            primary_key=True,
        ),
        sa.Column(
            "tariff_id",
            sa.Integer(),
            sa.ForeignKey("student_tariffs.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("used_minutes", sa.Integer(), server_default="0", nullable=False),
        sa.Column("due_minutes", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "weekend_minutes",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        *_people(),
        sa.CheckConstraint(
            "used_minutes >= 0 AND due_minutes >= 0 AND weekend_minutes >= 0",
            name="pupil_opening_minutes_not_negative",
        ),
        sa.CheckConstraint(
            "used_minutes % 15 = 0 AND due_minutes % 15 = 0 "
            "AND weekend_minutes % 15 = 0",
            name="pupil_opening_minutes_by_quarter",
        ),
        sa.CheckConstraint(
            "confirmed_at IS NOT NULL "
            "OR (used_minutes = 0 AND due_minutes = 0 AND weekend_minutes = 0)",
            name="pupil_opening_minutes_once_confirmed",
        ),
    )

    op.execute(
        "INSERT INTO accounting_openings (id, money_from) VALUES (1, '2026-11-16')",
    )
    for table, role in (
        ("teacher_openings", "teachers"),
        ("pupil_openings", "students"),
    ):
        op.execute(
            f"INSERT INTO {table} (tax_code) SELECT r.tax_code FROM {role} r {_ACTIVE}",
        )


def downgrade() -> None:
    op.drop_table("pupil_openings")
    op.drop_table("teacher_openings")
    op.drop_table("accounting_openings")
