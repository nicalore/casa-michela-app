"""The monthly summary of teachers: confirmed mode, volunteering by hand, daily hour,
and the notification of a changed unpaid hour

Revision ID: a3f8d2c61e94
Revises: b5e9a3c71d28
Create Date: 2026-11-09
"""

import sqlalchemy as sa

from alembic import op

revision = "a3f8d2c61e94"
down_revision = "b5e9a3c71d28"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_kind_enum ADD VALUE IF NOT EXISTS "
            "'VOLUNTEERING_CHANGED'"
        )

    op.add_column(
        "confirmed_hours",
        sa.Column(
            "mode",
            sa.String(20),
            server_default="presence",
            nullable=False,
        ),
    )
    op.create_check_constraint(
        op.f("ck_confirmed_hours_confirmed_hours_mode_valid"),
        "confirmed_hours",
        "mode IN ('presence', 'online')",
    )

    # The working copy knows the mode; without one, several stretches were online.
    op.execute(
        """
        UPDATE confirmed_hours ch SET mode = hc.mode
        FROM hours_corrections hc
        WHERE hc.date = ch.date AND hc.band = ch.band
          AND hc.teacher_tax_code = ch.teacher_tax_code
        """,
    )
    op.execute(
        """
        UPDATE confirmed_hours ch SET mode = 'online'
        WHERE NOT EXISTS (
            SELECT 1 FROM hours_corrections hc
            WHERE hc.date = ch.date AND hc.band = ch.band
              AND hc.teacher_tax_code = ch.teacher_tax_code
        )
        AND (
            SELECT count(*) FROM confirmed_hours other
            WHERE other.date = ch.date AND other.band = ch.band
              AND other.teacher_tax_code = ch.teacher_tax_code
        ) > 1
        """,
    )

    op.alter_column("confirmed_volunteering", "start_time", nullable=True)
    op.alter_column("confirmed_volunteering", "end_time", nullable=True)
    # The old end-after-start check passes null times: it stays as it is.
    op.create_check_constraint(
        op.f("ck_confirmed_volunteering_confirmed_volunteering_whole"),
        "confirmed_volunteering",
        "(start_time IS NULL) = (end_time IS NULL)",
    )

    # Only volunteering written by hand stays fixed; the rest follows the rule.
    op.execute(
        """
        DELETE FROM confirmed_volunteering cv
        WHERE NOT EXISTS (
            SELECT 1 FROM hours_corrections hc
            WHERE hc.date = cv.date AND hc.band = cv.band
              AND hc.teacher_tax_code = cv.teacher_tax_code
              AND hc.volunteer_set
        )
        """,
    )
    op.execute(
        """
        INSERT INTO confirmed_volunteering (teacher_tax_code, date, band)
        SELECT hc.teacher_tax_code, hc.date, hc.band
        FROM hours_corrections hc
        WHERE hc.volunteer_set AND hc.volunteer_start IS NULL
          AND EXISTS (
              SELECT 1 FROM confirmed_hours ch
              WHERE ch.date = hc.date AND ch.band = hc.band
                AND ch.teacher_tax_code = hc.teacher_tax_code
          )
        ON CONFLICT DO NOTHING
        """,
    )

    op.create_table(
        "daily_volunteering_months",
        sa.Column("teacher_tax_code", sa.String(16), primary_key=True),
        sa.Column("month", sa.Date(), primary_key=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="daily_volunteering_first_day",
        ),
    )


def downgrade() -> None:
    # The enum value stays: Postgres cannot drop one.
    op.execute("DELETE FROM notifications WHERE kind::text = 'VOLUNTEERING_CHANGED'")
    op.execute(
        "DELETE FROM muted_notification_kinds "
        "WHERE kind::text = 'VOLUNTEERING_CHANGED'"
    )
    op.drop_table("daily_volunteering_months")

    op.execute("DELETE FROM confirmed_volunteering WHERE start_time IS NULL")
    op.drop_constraint(
        op.f("ck_confirmed_volunteering_confirmed_volunteering_whole"),
        "confirmed_volunteering",
        type_="check",
    )
    op.alter_column("confirmed_volunteering", "end_time", nullable=False)
    op.alter_column("confirmed_volunteering", "start_time", nullable=False)

    op.drop_constraint(
        op.f("ck_confirmed_hours_confirmed_hours_mode_valid"),
        "confirmed_hours",
        type_="check",
    )
    op.drop_column("confirmed_hours", "mode")
